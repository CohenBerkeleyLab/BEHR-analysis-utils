function [ varargout ] = compare_old_new_profiles( date_in, new_wrf_dir, old_wrf_dir, daily_or_monthly, utc_hour )
%COMPARE_OLD_NEW_PROFILES Compare v2 and v3 BEHR WRF profiles
%   COMPARE_OLD_NEW_PROFILES( DATE_IN, NEW_WRF_DIR, OLD_WRF_DIR ) reads the
%   version 2 WRF NO2 profiles for DATE_IN from OLD_WRF_DIR and compares
%   them to the version 3 WRF profiles stored in NEW_WRF_DIR. Will ask
%   interactively if you wish to compare against new daily or monthly
%   profiles and (if using daily profiles) which UTC hour to use. This
%   plots the old profiles, new profiles, old profiles interpolated to the
%   new profiles' coordinates, and the absolute difference them using the
%   slice GUI so you can examine a whole domain at once.
%
%   COMPARE_OLD_NEW_PROFILES( ___, DAILY_OR_MONTHLY, UTC_HOUR ) allows you
%   to specify whether to use daily or monthly new profiles and, if daily,
%   which UTC hour in order to skip the interactive questions.
%   DAILY_OR_MONTHLY must be the string 'daily' or 'monthly' and UTC_HOUR
%   must be a scalar number between 0 and 23.
%
%   [ OLD_PROF, NEW_PROF, OLD_PROF_INTERP ] = COMPARE_OLD_NEW_PROFILES( ___ )
%   will skip plotting the profiles and instead return them. All the
%   outputs are structures with the fields Longitude, Latitude, Pressure,
%   and NO2_profile. This works with either previous syntax.

E = JLLErrors;
if ~exist(new_wrf_dir,'dir')
    E.dir_dne(new_wrf_dir)
end
if ~exist(old_wrf_dir,'dir')
    E.dir_dne(old_wrf_dir)
end

% Load old profiles
old_prof_file = sprintf('m%02d_NO2_profile.mat',month(date_in));
O = load(fullfile(old_wrf_dir, old_prof_file));
old_prof = O.PROFILE;
old_prof.NO2_profile = permute(old_prof.NO2_profile,[2 3 1]);

% Load new profiles
if ~exist('daily_or_monthly', 'var')
    daily_or_monthly = ask_multichoice('Daily or monthly profiles?', {'daily','monthly'}, 'list', true);
end

if strcmpi(daily_or_monthly, 'daily')
    if ~exist('utc_hour', 'var')
        utc_hour = ask_number('Enter the UTC hour to pick the new profiles from', 'testfxn', @(x) x >= 0 && x <= 23 && mod(x,1) == 0, 'testmsg', 'Value must be a whole number between 0 and 23');
    elseif ~isnumeric(utc_hour) || ~isscalar(utc_hour) || utc_hour < 0 || utc_hour > 23
        E.badinput('utc_hour must be a scalar number between 0 and 23');
    end
    wrf_pattern = sprintf('wrfout*%s_%02d-*',datestr(date_in, 'yyyy-mm-dd'),utc_hour);
    
    F = dir(fullfile(new_wrf_dir, wrf_pattern));
    if isempty(F)
        E.filenotfound('File matching pattern %s in %s', wrf_pattern, new_wrf_dir);
    end
    wrf_file = glob({F.name},sprintf('.*%02d[:-]00[:-]00', utc_hour));
    if isempty(wrf_file)
        warning('File for %02d:30 UTC not found, using %s instead', utc_hour, F(1).name);
        wrf_file = {F(1).name};
    end
else
    wrf_pattern = sprintf('WRF_BEHR_monthly_%s.nc', datestr(date_in, 'mm'));
    wrf_file = fullfile(new_wrf_dir, wrf_pattern);
    if ~exist(wrf_file, 'file')
        E.filenotfound('File %s in %s', wrf_pattern, new_wrf_dir);
    end
end
wi = ncinfo(wrf_file);


new_prof.Longitude = double(ncread(wi.Filename, 'XLONG'));
new_prof.Latitude = double(ncread(wi.Filename, 'XLAT'));
new_prof.Pressure = double(ncread(wi.Filename, 'pres'));
new_prof.NO2_profile = double(ncread(wi.Filename, 'no2'));

% Interpolate the old profiles to the new coordinates
old_prof_interp = interp_profiles(old_prof, new_prof);
    
if nargout == 0
    % Plot the old profiles without interpolating
    [slon, slat] = state_outlines('not', 'ak', 'hi');
    plot_slice_gui(old_prof.NO2_profile, old_prof.Longitude, old_prof.Latitude, slon, slat, 'Old profiles, no interp');
    % Plot the both sets of profiles and the differences
    plot_slice_gui(old_prof_interp.NO2_profile, old_prof_interp.Longitude, old_prof_interp.Latitude, slon, slat, 'Old profiles, after interp');
    plot_slice_gui(new_prof.NO2_profile, new_prof.Longitude, new_prof.Latitude, slon, slat, 'New profiles');
    plot_slice_gui(new_prof.NO2_profile - old_prof_interp.NO2_profile, old_prof_interp.Longitude, old_prof_interp.Latitude, slon, slat, 'New profiles - old interp profiles');
    
    if strcmpi(ask_multichoice('Add new_prof and old_prof_interp to workspace?',{'y','n'}),'y');
        putvar(new_prof, old_prof_interp);
    end
else
    varargout = {old_prof, new_prof, old_prof_interp};
end
end

function op_interp = interp_profiles(old_prof, new_prof)
op_interp.Longitude = new_prof.Longitude;
op_interp.Latitude = new_prof.Latitude;
op_interp.Pressure = new_prof.Pressure;

lonv = old_prof.Longitude;
latv = old_prof.Latitude;
presv = old_prof.Pressure;

lonq = new_prof.Longitude;
latq = new_prof.Latitude;
presq = new_prof.Pressure;

sz = size(new_prof.NO2_profile);
op_no2_tmp = nan(sz(1), sz(2), size(old_prof.NO2_profile,3));

% First interpolate each level to lon/lat coordinates
for a=1:size(old_prof.NO2_profile,3)
    fprintf('Interpolating to lat/lon - level %d\n', a)
    F = scatteredInterpolant(lonv(:), latv(:), reshape(old_prof.NO2_profile(:,:,a),[],1));
    op_no2_tmp(:,:,a) = F(lonq, latq);
end

% Now interpolate in log-log space for the pressure coordinate
op_interp.NO2_profile = nan(size(new_prof.NO2_profile));
% Ensure no negative values exist for the log
op_no2_tmp(op_no2_tmp<0) = nan;
p_vec = log(presv(:));
for a=1:prod(sz(1:2))
    fprintf('Vertical interp: %d of %d\n', a, prod(sz(1:2)));
    [x,y] = ind2sub(sz(1:2),a);
    no2_vec = log(squeeze(op_no2_tmp(x,y,:)));
    pq_vec = log(squeeze(presq(x,y,:)));
    
    no2_vec_tmp = interp1(p_vec, no2_vec, pq_vec);
    op_interp.NO2_profile(x,y,:) = exp(no2_vec_tmp);
end


end