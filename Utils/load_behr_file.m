function [ varargout ] = load_behr_file( file_date, prof_mode, region, version )
%LOAD_BEHR_FILE Convenience function to load a BEHR file for a given date
%
%   LOAD_BEHR_FILE( FILE_DATE, PROF_MODE, REGION ) Loads the BEHR .mat file
%   for FILE_DATE processed with PROF_MODE profiles (usually 'daily' or
%   'monthly') for the region REGION (default is 'us') from the standard
%   behr_mat_dir given in behr_paths. Places the variables Data and OMI
%   directly in the base workspace.
%
%   [ Data, OMI ] = LOAD_BEHR_FILE( FILE_DATE ) Returns Data and OMI as
%   outputs instead.
%
%   [ Data ] = LOAD_BEHR_FILE( FILE_DATE ) Will only load Data, which can
%   be faster.

if ~exist('region','var')
    region = 'us';
end

if ~exist('version','var')
    file_name = behr_filename(file_date, prof_mode, region);
else
    file_name = behr_filename(file_date, prof_mode, region, '.mat', version);
end

if nargout == 1
    load_vars = {'Data'};
else
    load_vars = {'Data', 'OMI'};
end

behr_file = fullfile(behr_paths.BEHRMatSubdir(region, prof_mode), file_name);
D = load(behr_file, load_vars{:});
if nargout == 0
    Data = D.Data;
    OMI = D.OMI;
    putvar(Data,OMI);
else
    varargout{1} = D.Data;
    if nargout > 1
        varargout{2} = D.OMI;
    end
end

end

