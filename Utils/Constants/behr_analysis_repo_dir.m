function [ p ] = behr_analysis_repo_dir(  )
%BEHR_ANALYSIS_REPO_DIR Yields the root directory of the BEHR-analysis repo

mydir = fileparts(mfilename('fullpath'));
if isempty(regexp(mydir, 'BEHR-analysis-utils/Utils/Constants$','once'))
    warning('BEHR_ANALYSIS_REPO_DIR should be in the Utils/Constants subdirectory of the BEHR-analysis-utils repository. This does not appear to be the case.');
end

oldwd = cd(fullfile(mydir, '..', '..'));
try
    p = pwd;
catch err
    cd(oldwd);
    rethrow(err);
end
cd(oldwd);


end

