function [ varargout ] = load_behr_file( file_date )
%LOAD_BEHR_FILE Convenience function to load a BEHR file for a given date
%
%   LOAD_BEHR_FILE( FILE_DATE ) Loads the BEHR .mat file for FILE_DATE from
%   the standard behr_mat_dir given in behr_paths. Places the variables
%   Data and OMI directly in the base workspace.
%
%   [ Data, OMI ] = LOAD_BEHR_FILE( FILE_DATE ) Returns Data and OMI as
%   outputs instead.


behr_file = fullfile(behr_paths.behr_mat_dir, behr_filename(file_date));
D = load(behr_file);
if nargout == 0
    Data = D.Data;
    OMI = D.OMI;
    putvar(Data,OMI);
else
    varargout{1} = D.Data;
    varargout{2} = D.OMI;
end

end

