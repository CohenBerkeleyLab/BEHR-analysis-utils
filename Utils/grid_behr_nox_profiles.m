function grid_behr_nox_profiles(start_date, end_date, varargin)
%GRID_BEHR_NOX_PROFILES Grid NO and NO2 profiles to BEHR standard grid
%   GRID_BEHR_NOX_PROFILES(START_DATE, END_DATE) grids NO and NO2 profiles
%   between START_DATE and END_DATE, which may be noncontinguous ranges.
%   Saves results to current directory.
%
%   Parameters:
%
%       'no2_profile_path' - where to look for WRF files. Default will
%       search within rProfile_WRF.
%
%       'region' - which region to grid. Options: 'us', 'hk'.
%
%       'save_dir' - where to save the output files. Default is current
%       directory.

E = JLLErrors;
p = advInputParser;

p.addParameter('no2_profile_path', '');
p.addParameter('region', 'us');
p.addParameter('save_dir', '.');

p.parse(varargin{:});
pout = p.Results;

no2_profile_path = pout.no2_profile_path;
region = pout.region;
save_dir = pout.save_dir;

start_date = validate_date(start_date);
end_date = validate_date(end_date);
dvec = make_datevec(start_date, end_date);
for i_date = 1:numel(dvec)
    [Data, OMI] = load_behr_file(dvec(i_date), 'daily', region); 
    
    prof_fns = {'Longitude', 'Latitude', 'FoV75CornerLongitude',...
        'FoV75CornerLatitude', 'FoV75Area', 'Grid', 'pressure',...
        'no2', 'no', 'wrf_file', 'BEHRQualityFlags'};
    Profiles = make_empty_struct_from_cell(prof_fns);
    Profiles = repmat(Profiles, size(Data));
    
    grid_fns = {'Longitude', 'Latitude', 'Areaweight', 'no', 'no2', 'pressure', 'wrf_file'};
    GriddedProfs = make_empty_struct_from_cell(grid_fns);
    GriddedProfs = repmat(GriddedProfs, size(Data));
    
    for i_orbit = 1:numel(Data)
        for i_fn = 1:numel(prof_fns)
            fn = prof_fns{i_fn};
            if isfield(Data, fn)
                Profiles(i_orbit).(fn) = Data(i_orbit).(fn);
            end
        end
        
        time = Data(i_orbit).Time;
        loncorns = Data(i_orbit).FoV75CornerLongitude;
        latcorns = Data(i_orbit).FoV75CornerLatitude;
        globe_terheight = Data(i_orbit).GLOBETerrainHeight;
        pressure = behr_pres_levels();
        
        [no2Profile, ~, wrf_file, ~, ~, ~, ~, ~, ~, extra_profs] = rProfile_WRF(...
            dvec(i_date), 'daily', region, loncorns, latcorns,...
            time, globe_terheight, pressure, no2_profile_path, 'extra_wrf_vars', {'no'});
        
        no2Profile = permute(no2Profile, [2 3 1]);
        no = permute(extra_profs{1}, [2 3 1]);
        
        Profiles(i_orbit).pressure = pressure;
        Profiles(i_orbit).no2 = no2Profile;
        Profiles(i_orbit).no = no;
        Profiles(i_orbit).wrf_file = wrf_file;
        
        Areaweight = repmat(1 ./ Data(i_orbit).FoV75Area, size(no, 1), 1, size(no,3));
        
        GriddedProfs(i_orbit).Longitude = Data(i_orbit).Grid.GridLon;
        GriddedProfs(i_orbit).Latitude = Data(i_orbit).Grid.GridLat;
        GriddedProfs(i_orbit).pressure = pressure;
        GriddedProfs(i_orbit).wrf_file = wrf_file;
        GriddedProfs(i_orbit).BEHRQualityFlags = OMI(i_orbit).BEHRQualityFlags;
        [GriddedProfs(i_orbit).no2, GriddedProfs(i_orbit).Areaweight] = cvm_generic_wrapper(loncorns, latcorns, no2Profile,...
            Data(i_orbit).Grid, 'weights', Areaweight);
        GriddedProfs(i_orbit).no = cvm_generic_wrapper(loncorns, latcorns, no, Data(i_orbit).Grid, 'weights', Areaweight);
    end
    
    savename = sprintf('WRF_BEHR_PROFILES_%s.mat', datestr(dvec(i_date), 'yyyymmdd'));
    save_helper(fullfile(save_dir, savename), Data, OMI);
end
end

function save_helper(filename, Data, OMI)
save(filename, 'Data', 'OMI');
end