function results = wrf_time_average(start_dates,end_dates,variables,varargin)
%WRF_TIME_AVERAGE Average WRF data for certain hours over a given time period
%   RESULTS = WRF_TIME_AVERAGE( START_DATES, END_DATES, VARIABLES )
%   Averages the VARIABLES (a cell array of WRF variables) for WRF files
%   that coincide with an OMI overpass between START_DATES and END_DATES.
%   The start and end dates may be any format understood by MAKE_DATEVEC.
%
%   Parameters:
%       'domain' - the WRF domain to load data for. Must be understood as a
%       region by BEHRMatchedWRFFiles. 'us' is default.
%
%       'matched_wrf_files' - alternatively, use this to pass an instance
%       of BEHRMatchedWRFFiles to use to find the WRF files for the
%       requested dates. Passing this is advantageous if you will be doing
%       lots of short averages within one month, as the instance can keep a
%       list of all WRF files for that month without having to rebuild it
%       every time this function is called.
%
%       'processing' - a structure that controls how certain quantities are
%       preprocessed before being averaged. This allows you to compute
%       certain quantities derived from WRF variables that aren't defined
%       in READ_WRF_PREPROC. Each field of processing must be names as one
%       of the variables requested, and must itself be a structure with two
%       fields:
%           * 'variables' - a cell array of variables from the WRF file
%           required to compute the desired quantity.
%           * 'proc_fxn' - a handle to a function that accepts a structure
%           returned by READ_WRF_VARS (which will have fields named for
%           each WRF variable read from all files) and returns the computed
%           quantity.
%       An easy example would be if pressure and altitude were not defined
%       in READ_WRF_PREPROC, they could be specified here by including
%       'pressure' and 'altitude' in VARIABLES and making 'processing' the
%       following structure:
%
%           processing.pressure = struct('variables', {{'P','PB'}},
%               'proc_fxn', @(Wrf) Wrf.P + Wrf.PB);
%           processing.altitude = struct('variables', {{'PH', 'PHB'}},
%               'proc_fxn', @(Wrf) (Wrf.PH + Wrf.PHB)/9.81);

p = advInputParser;
p.addParameter('domain', 'us');
p.addParameter('utc_range', nan); % unused - intended to allow averaging w/o BEHR files to match
p.addParameter('utc_hour', nan); % unused - ditto
p.addParameter('local_hour', nan); % unused - ditto
p.addParameter('processing', struct());
p.addParameter('matched_wrf_files', []);

p.parse(varargin{:});
pout = p.Results;

domain = pout.domain;
processing = pout.processing;
% [time_mode, time_value] = setup_time_mode(pout);
dvec = make_datevec(start_dates, end_dates);
% file_utc_range = get_utc_range_to_load(time_mode, time_value, dvec(1), domain);

MatchedFiles = pout.matched_wrf_files;
if isempty(MatchedFiles)
    MatchedFiles = BEHRMatchedWRFFiles('region',domain);
end
local_hour = 13.5;

% Handle quantities that need intermediate processing. Make sure their
% variables are in the list of variables to load but they themselves are
% not.
xx_keep = true(size(variables));
extra_vars = {};
for i_var = 1:numel(variables)
    varname = variables{i_var};
    if isfield(processing, varname)
        xx_keep(i_var) = false;
        extra_vars = veccat(extra_vars, processing.(varname).variables);
    end
end
variables_to_load = unique(veccat(variables(xx_keep), extra_vars, 'column'));


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
    
    Wrf = read_wrf_vars('', files, variables_to_load, 'squeeze', 'as_struct');
    utc_hours = hour(date_from_wrf_filenames(files));
    
    for i_var = 1:numel(variables)
        this_var = variables{i_var};
        if i_date == 1
            Avgs.(this_var) = RunningAverage();
        end
        
        if isfield(processing, this_var)
            quantity = processing.(this_var).proc_fxn(Wrf);
        else
            quantity = Wrf.(this_var);
        end
        this_day_avg = wrf_day_weighted_average(xlon, local_hour, utc_hours, quantity);
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
