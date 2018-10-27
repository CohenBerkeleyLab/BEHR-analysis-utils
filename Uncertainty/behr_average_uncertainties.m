function behr_average_uncertainties(varargin)
%BEHR_AVERAGE_UNCERTAINTIES Create averages of the uncertainty files
%   To calculate the effect of each varied parameter on the AMFs and NO2
%   columns, first we want to make monthly averages of the percent
%   differences. Because of the structure hierarchy of the uncertainty
%   files, we need this function to handle that, rather than using
%   behr_time_average directly.

E = JLLErrors;

p = inputParser;
p.addParameter('avg_years', 2012);
p.addParameter('output_dir', '');
p.addParameter('region', 'us');
p.addParameter('overwrite', false);

p.parse(varargin{:});
pout = p.Results;
% output directory will be set for each parameter
region = pout.region;
overwrite = pout.overwrite;
avg_years = pout.avg_years;

% The steps we need to take are:
%   1) Loop over each varied parameter
%   2) Find which months to average
%   3) Average the perturbed parameter from original BEHR files for those
%   months
%   4) For each month, average the perturbed parameter and the percent
%   differences from the error analysis files.

params = get_param_list(region);

for i_param = 1:numel(params)
    this_param = params{i_param};
    output_dir = set_output_dir(pout.output_dir, this_param);
    month_files = list_files_for_complete_months(region, this_param, avg_years);
    for i_month = 1:numel(month_files)
        savename = sprintf('BEHR_%s_uncertainty_avg_%s.mat', this_param, month_files(i_month).dstring);
        full_savename = fullfile(output_dir, savename);
        if ~overwrite && exist(full_savename, 'file')
            fprintf('%s exists; skipping\n', full_savename);
            continue
        end
        
        % Load the first uncertainty file to see if the perturbed parameter
        % is one of the fields
        these_files = month_files(i_month).files;
        TmpError = load(these_files(1).name);
        ErrorData = TmpError.ErrorData;
        n_changes = numel(ErrorData);
        average_perturbed_param = isfield(ErrorData(1).DeltaGrid, this_param);
        avg_fields = {'PercentChangeNO2','PercentChangeNO2Vis','PercentChangeAMF','PercentChangeAMFVis'};
        if average_perturbed_param
            avg_fields{end+1} = this_param;
            base_field = sprintf('%sBase', this_param);
        end
        
        % Set up to do the averages. Must do it this way to ensure each
        % running average is a unique instance.
        running_avgs = struct();
        for i_change = 1:n_changes
            for i_field = 1:numel(avg_fields)
                running_avgs(i_change).(avg_fields{i_field}) = RunningAverage();
            end
            if average_perturbed_param
                running_avgs(i_change).(base_field) = RunningAverage();
            end
        end
        
        % Now we can loop over each day. If the perturbed parameter is a
        % field in the OMI structs, include its base value as well.
        for i_file = 1:numel(these_files)
            fprintf('Loading %s\n', these_files(i_file).name);
            EF = load(these_files(i_file).name);
            ErrorData = EF.ErrorData;
            
            % At the moment only daily files are used in the error
            % analysis
            Base = load(fullfile(behr_paths.BEHRUncertSubdir(region), 'BaseCase', behr_filename(date_from_behr_filenames(these_files(i_file).name), 'daily', region)));
            BaseGrid = Base.OMI;
            if numel(BaseGrid) ~= numel(ErrorData(i_change).DeltaGrid)
                E.notimplemented('BaseGrid and DeltaGrid have different numbers of orbits (really this should not happen)')
            end
            
            
            for i_change = 1:numel(ErrorData)
                for i_orbit = 1:numel(ErrorData(i_change).DeltaGrid)
                    this_DeltaGrid = ErrorData(i_change).DeltaGrid(i_orbit);
                    this_BaseGrid = BaseGrid(i_orbit);
                    % Check that the areaweights are the same between the
                    % DeltaGrid and BaseGrid since currently we rely on the
                    % BEHRQualityFlags from the BaseGrid to handle pixel
                    % rejection. This also ensures that the same pixels are
                    % rejected as would be in the standard retrieval so the
                    % statistics of the error analysis should match up.
                    chk = difftol(this_DeltaGrid.Areaweight, this_BaseGrid.Areaweight);
                    chk = chk | this_DeltaGrid.Areaweight == 0 | this_BaseGrid.Areaweight == 0;
                    if ~all(chk(:))
                        warning('%d gridcells'' difference between DeltaGrid areaweight and BaseGrid areaweight exceeds tolerance and are not 0 in either areaweight', sum(~chk(:)));
                    end
                    
                    % All fields have the same areaweight, so we can just
                    % reject once. However, we need to use different
                    % Areaweights for the perturbed qualities because
                    % sometimes the perturbation causes
                    %this_DeltaGrid.BEHRQualityFlags = this_BaseGrid.BEHRQualityFlags;
                    this_DeltaGrid = omi_pixel_reject(this_DeltaGrid, 'behr-error');
                    areawt = this_DeltaGrid.Areaweight;
                    this_BaseGrid = omi_pixel_reject(this_BaseGrid, 'behr-error');
                    base_areawt = this_BaseGrid.Areaweight;
                    for i_field = 1:numel(avg_fields)
                        running_avgs(i_change).(avg_fields{i_field}).addData(this_DeltaGrid.(avg_fields{i_field}), areawt);
                    end
                    
                    if average_perturbed_param
                        running_avgs(i_change).(base_field).addData(this_BaseGrid.(this_param), base_areawt);
                    end
                end
            end
        end
        
        ErrorAvg = rmfield(ErrorData, {'Delta', 'DeltaGrid'});
        avg_fns = fieldnames(running_avgs);
        for i_change = 1:numel(ErrorData)
            for i_field = 1:numel(avg_fns)
                ErrorAvg(i_change).(avg_fns{i_field}) = running_avgs(i_change).(avg_fns{i_field}).getWeightedAverage();
            end
        end
        
        save(full_savename, 'ErrorAvg');
    end
end


    function out_dir = set_output_dir(base_dir, param)
        if isempty(base_dir)
            out_dir = fullfile(behr_paths.BEHRUncertSubdir(region), param);
        else
            out_dir = base_dir;
        end
    end

end



function params = get_param_list(region)
% Assume that each of the varied parameters is stored in a subdirectory of
% the regional uncertainty directory. This is how
% behr_generate_uncertainty_files() is configured to work.
F = dir(behr_paths.BEHRUncertSubdir(region));
% Keep only directories that are not '.' and '..'
file_names = {F.name};
xx_keep = cellfun(@(x) ~regcmp(x, '\.{1,2}'), file_names) & [F.isdir];
xx_keep = xx_keep & ~strcmp(file_names, 'BaseCase');
params = {F(xx_keep).name};
end

function month_files = list_files_for_complete_months(region, param, years)
% List all BEHR files in the parameter subdirectory, then find unique
% months. For each unique month, test if it has all the expected days. If
% not, omit it; if so, create an entry in month_files for that month;
E = JLLErrors;
F = dirff(fullfile(behr_paths.BEHRUncertSubdir(region), param, 'OMI_BEHR*.mat'));
behr_dates = date_from_behr_filenames(F);
behr_year = unique(year(behr_dates));
if numel(behr_year) > 1
    E.notimplemented('Collecting monthly uncertainty files over >1 year');
end

behr_years = year(behr_dates);
behr_months = month(behr_dates);

month_files = struct('month', {[1 2 12], 3:5, 6:8, 9:11}, 'dstring', {'DJF','MAM','JJA','SON'}, 'files', []);

for i_month = 1:numel(month_files)
    xx_month = ismember(behr_months, month_files(i_month).month) & ismember(behr_years, years);
    month_files(i_month).files = F(xx_month);
end

end
