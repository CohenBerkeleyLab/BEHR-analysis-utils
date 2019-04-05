classdef BEHRMatchedWRFFiles < handle
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        DEBUG_LEVEL;
    end

    properties(SetAccess = protected)
        last_month;
        last_year;
        last_files;
        behr_region;
    end
    
    methods
        function obj = BEHRMatchedWRFFiles(varargin)
            %UNTITLED Construct an instance of this class
            %   Detailed explanation goes here
            p = advInputParser;
            p.addParameter('region', 'us');
            p.addParameter('DEBUG_LEVEL', 0);
            p.parse(varargin{:});
            pout = p.Results;
            
            obj.last_month = nan;
            obj.last_year = nan;
            obj.last_files = [];
            obj.behr_region = pout.region;
            obj.DEBUG_LEVEL = pout.DEBUG_LEVEL;
        end
        
        function [wrf_files, behr_data] = get_files_for_date(obj,date_in)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
            try
                if month(date_in) == obj.last_month && year(date_in) == obj.last_year
                    obj.log(1, '     Using existing list of WRF files\n');
                    [wrf_files, ~, behr_data] = obj.closest_wrf_file_in_time(date_in, obj.last_files);
                else
                    obj.log(1, '     New month: need to get the directory listing\n');
                    [wrf_files, obj.last_files, behr_data] = obj.closest_wrf_file_in_time(date_in, []);
                    obj.last_month = month(date_in);
                    obj.last_year = year(date_in);
                end
            catch err
                if strcmp(err.identifier, 'MATLAB:load:couldNotReadFile')
                    obj.log(1, 'Cannot load file for %s\n', datestr(date_in));
                    wrf_files = {};
                elseif strcmp(err.identifier, 'find_wrf_path:dir_does_not_exist')
                    obj.log(1, 'Could not find any WRF files for %s\n', datestr(date_in));
                    wrf_files = {};
                else
                    rethrow(err)
                end
            end
        end
    end
    
    methods(Access = protected)
        
        function [wrf_files, F, Data] = closest_wrf_file_in_time(obj, date_in, F)
            % Finds the WRF files closest in time to each swath in the BEHR
            % file for the DATE_IN. Returns the list of files as a cell
            % array. Can pass F in, which should be a structure returned
            % from DIRFF() of all relevant WRF files, which will speed up
            % this method.
            Data = load_behr_file(date_in, 'monthly', obj.behr_region); % we only care about Time, which is the same in both monthly and daily products
            wrf_files = cell(size(Data));
            wrf_dir = find_wrf_path('us','daily',date_in);
            if isempty(F)
                F = dirff(fullfile(wrf_dir, 'wrfout*'));
            end
            wrf_dates = date_from_wrf_filenames(F);
            for a=1:numel(Data)
                utc_datenum = omi_time_conv(nanmean(Data(a).Time(:)));
                [~, i_date] = min(abs(wrf_dates - utc_datenum));
                wrf_files{a} = F(i_date).name;
            end
        end
        
        function log(obj, level, msg, varargin)
            if obj.DEBUG_LEVEL >= level
                fprintf(msg, varargin{:});
            end
        end
        
    end
end

