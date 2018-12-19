function results = wrf_time_average(start_dates,end_dates,variables,varargin)
%UNTITLED2 Summary of this function goes here
%   Detailed explanation goes here

p = advInputParser;
p.addParameter('domain', 'us');
p.addParameter('utc_range', nan);
p.addParameter('utc_hour', nan);
p.addParameter('local_hour', nan);

p.parse(varargin{:});
pout = p.Results;

domain = pout.domain;
% [time_mode, time_value] = setup_time_mode(pout);
dvec = make_datevec(start_dates, end_dates);
% file_utc_range = get_utc_range_to_load(time_mode, time_value, dvec(1), domain);

MatchedFiles = BEHRMatchedWRFFiles('region',domain);
local_hour = 13.5;


for i_date = 1:numel(dvec)
    fprintf('Loading WRF data for %s\n', datestr(dvec(i_date)));
    files = MatchedFiles.get_files_for_date(dvec(i_date));
    if numel(files) == 0
        fprintf('Could not load files for %s\n', datestr(dvec(i_date)))
        continue
    end
    
    xlon = ncread(files{1},'XLONG');
    xlat = ncread(files{1},'XLAT');
    if i_date == 1
        xlon_check = xlon;
        xlat_check = xlat;
    else
        if ~isequal(xlon, xlon_check) || ~isequal(xlat, xlat_check)
            E.callError('inconsistent_lon', 'Lon in %s is not the same as the first file', files{1});
        end
    end
    
    Wrf = read_wrf_vars('', files, variables, 'squeeze', 'as_struct');
    utc_hours = hour(date_from_wrf_filenames(files));
    
    for i_var = 1:numel(variables)
        this_var = variables{i_var};
        if i_date == 1
            Avgs.(this_var) = RunningAverage();
        end
        this_day_avg = wrf_day_weighted_average(xlon, local_hour, utc_hours, Wrf.(this_var));
        Avgs.(this_var).addData(this_day_avg{1});
    end
end

results.XLONG = xlon_check;
results.XLAT = xlat_check;
for i_var = 1:numel(variables)
    this_var = variables{i_var};
    results.(this_var) = Avgs.(this_var).getWeightedAverage();
end

end

function [time_mode, time_value] = setup_time_mode(pout)
E = JLLErrors;

time_mode = '';
time_value = nan;

time_fields = {'utc_range', 'utc_hour', 'local_hour'};
for i = 1:numel(time_fields)
    this_tf = time_fields{i};
    in_val = pout.(this_tf);
    if ~isnan(in_val)
        if isnan(time_value)
            time_mode = this_tf;
            time_value = in_val;
        else
            E.badinput('Mutually exclusive parameters "%s" and "%s" both given', time_mode, this_tf);
        end
    end
end

end

function load_range = get_utc_range_to_load(time_mode, time_value, first_date, domain)
switch lower(time_mode)
    case 'utc_hour'
        load_range = [time_value, time_value];
    case 'utc_range'
        load_range = time_value;
    case 'local_hour'
        wrf_file = find_wrf_path(domain, 'daily', first_date, 'fullpath');
        wrf_lon = ncread(wrf_file, 'XLONG');
        utc_offsets = fix_away([min(wrf_lon(:)), max(wrf_lon(:))]);
        load_range = time_value - utc_offsets;
end
end

function files = get_files_for_date(curr_date, utc_range)
end

function x = fix_away(x)
% round x to the number further away from zero
x = fix(x) + sign(x);
end
