function [ varargout ] = omi_pixel_reject( omi, reject_mode, varargin )
%OMI_PIXEL_REJECT Set areaweight to 0 for any pixels that will adversely affect the accuracy of the BEHR NO2 map.
%   There are a number of criteria that need to be evaluated for an OMI
%   pixel before it can be reliably used as an NO2 measurement.  This
%   function will set the areaweight value to 0 for any pixel which fails
%   these criteria.
%
%   OMI = OMI_PIXEL_REJECT( OMI, 'none' ) Essentially a no-op, does
%   nothing. Useful only if iterating over fields and do not want to reject
%   any values for some fields. OMI must be a scalar structure.
%
%   OMI = OMI_PIXEL_REJECT( OMI, 'behr' ) Sets areaweight to 0 for any grid
%   cell that has the first bit of the BEHRQualityFlags field == 1.
%
%   OMI = OMI_PIXEL_REJECT( OMI, 'behr-error' ) Sets areaweight to 0 for any 
%   grid cell that has the second bit of the BEHRQualityFlags field == 1.
%
%   OMI = OMI_PIXEL_REJECT( OMI, 'detailed', REJECT_DETAIL ) Allows fine
%   control over exactly which pixels are rejected according to the
%   structure REJECT_DETAILS. This structure must have the fields:
%       cloud_type: 'omi', 'modis', or 'rad'. Sets which cloud product to
%           use when rejecting pixels by cloud fraction. 
%       cloud_frac: The maximum allowed cloud fraction in a pixel.  If
%           using OMI cloud product, 0.2 is recommended. With MODIS, 0 to
%           0.2 is recommended. With radiance, 0.5 is recommended.
%       row_anom_mode: Can be one of 4 values, 'AlwaysByRow',
%          'RowsByTime', 'XTrackFlags', and 'XTrackFlagsLight'.
%          'AlwaysByRow' will always reject pixels in the row affected by
%          the anomaly, regardless of whether the data occurs before or
%          after the anomaly reached that row. 'XTrackFlags' uses the row
%          anomaly flag in the OMNO2 product to reject pixels.  These are
%          the two recommended methods.
%       check_behr_amf: a scalar logical, if true, rejects pixels for which
%           the BEHR AMF is <= the minimum value defined by
%           BEHR_MIN_AMF_VAL()
%
%   In 'detailed' mode, a grid cell with mod(VcdQualityFlags, 2) ~= 0 will
%   always be rejected.
%
%   For more information on the row anomaly: see
%   http://www.knmi.nl/omi/research/product/rowanomaly-background.php
%
%   Parameters:
%
%       'weight_field' - which field to set weights to 0 in for bad pixels.
%       Default is 'Areaweight'. Not used if 'return_mode' set to
%       'logical'.
%
%       'return_mode' - how to mark bad pixels. Default is 'weight', which
%       set the field specified by 'weight_field' to 0 for bad pixels. May
%       also be 'logical', which returns a logical array the same size as
%       OMI.Longitude that is true for bad pixels.

E = JLLErrors;

p = inputParser;
p.addOptional('reject_details', struct(), @isstruct);
p.addParameter('weight_field', 'Areaweight', @ischar);
p.addParameter('return_mode', 'weight', @ischar);

p.parse(varargin{:});
pout = p.Results;

reject_details = pout.reject_details;
weight_field = pout.weight_field;
return_mode = pout.return_mode;

if ~isstruct(omi) || ~isscalar(omi)
    E.badinput('OMI must be a scalar structure');
end

allowed_reject_modes = {'none', 'behr', 'behr-error', 'detailed'};
if ~ischar(reject_mode) || ~ismember(reject_mode, allowed_reject_modes)
    E.badinput('REJECT_MODE must be one of the strings %s', strjoin(allowed_reject_modes, ', '))
end

cld_fields = struct('omi', 'CloudFraction', 'modis', 'MODISCloud', 'rad', 'CloudRadianceFraction');
allowed_row_modes = {'AlwaysByRow', 'RowsByTime', 'XTrackFlags', 'XTrackFlagsLight'};
if strcmp(reject_mode, 'detailed')
    req_details_fields = {'cloud_type', 'cloud_frac', 'row_anom_mode'};
    if any(~ismember(req_details_fields, fieldnames(reject_details)))
        E.badinput('The REJECT_DETAILS struct must have the following fields for REJECT_MODE == "%s": %s', reject_mode, strjoin(req_details_fields, ', '));
    end
    
    req_details = {'cloud_type', 'cloud_frac', 'row_anom_mode', 'check_behr_amf'};
    if ~exist('reject_details', 'var') || ~isstruct(reject_details) || any(~isfield(reject_details, req_details))
        E.badinput('If REJECT_MODE == ''detailed'', the third input must be a structure with fields %s', strjoin(req_details, ', '));
    elseif ~ismember(reject_details.cloud_type, fieldnames(cld_fields))
        E.badinput('The "cloud_type" field of the REJECT_DETAIL struct must be one of the strings %s', strjoin(fieldnames(cld_fields)));
    elseif ~isnumeric(reject_details.cloud_frac) || ~isscalar(reject_details.cloud_frac)
        E.badinput('The "cloud_frac" field of the REJECT_DETAIL struct must be a scalar number');
    elseif ~ismember(reject_details.row_anom_mode, allowed_row_modes)
        E.badinput('The "row_anom_mode" field of the REJECT_DETAIL struct must be one of the strings: %s', strjoin(allowed_row_modes, ', '));
    elseif ~isscalar(reject_details.check_behr_amf) || ~islogical(reject_details.check_behr_amf)
        E.badinput('The "check_behr_amf" field of the REJECT_DETAIL struct must be a scalar logical');
    end
end

% This is a hack to allow this function to be used with BEHR v2 files,
% which have vcdQualityFlags (lowercase v) instead of VcdQualityFlags
if isscalar(omi) && ~isfield(omi, 'VcdQualityFlags') && strcmpi(reject_mode, 'detailed')
    % This would fail if omi is not scalar, and we'll check for it being
    % scalar at the same time we look for VcdQualityFlags anyway
    remove_temp_flag_field = true;
    omi.VcdQualityFlags = omi.vcdQualityFlags;
else
    remove_temp_flag_field = false;
end


switch reject_mode
    case 'none'
        req_fields = {};
    case 'behr'
        req_fields = {'Areaweight', 'BEHRQualityFlags'};
    case 'behr-error'
        req_fields = {'Areaweight', 'BEHRQualityFlags'};
    case 'detailed'
        req_fields = {'Areaweight', 'XTrackQualityFlags', 'VcdQualityFlags', cld_fields.(reject_details.cloud_type)};
    otherwise
        E.notimplemented('Required fields not defined for REJECT_MODE == ''%s''', reject_mode);
end

% If just returning the bad pixel logical, we don't need Areaweight.
if strcmpi(return_mode, 'logical')
    unneeded_field = strcmp(req_fields, 'Areaweight');
    req_fields(unneeded_field) = [];
end

if ~isstruct(omi) || ~isscalar(omi) || (numel(req_fields) > 0 && any(~isfield(omi, req_fields)))
    E.badinput('OMI must be a scalar structure with the fields %s', strjoin(req_fields, ', '))
end

%%%%%%%%%%%%%%%%%
% MAIN FUNCTION %
%%%%%%%%%%%%%%%%%

if strcmpi(reject_mode, 'none')
    % do nothing. this allow us to average fields that should not have any
    % bad values, or at least their bad values are unrelated to what
    % generates bad values in the VCD.
elseif strcmpi(reject_mode, 'behr')
    % Reject pixels marked as low quality by the BEHRQualityFlags
    bad_pix = reject_by_behr_flags(omi.BEHRQualityFlags, 1);
elseif strcmpi(reject_mode, 'behr-error')
    % Reject pixels marked as having a critical error by the
    % BEHRQualityFlags
    bad_pix = reject_by_behr_flags(omi.BEHRQualityFlags, 2);
elseif strcmpi(reject_mode, 'detailed')
    sel_cloud_field = cld_fields.(reject_details.cloud_type);
    bad_pix = reject_by_details(reject_details, omi.(sel_cloud_field), omi.VcdQualityFlags, omi.XTrackQualityFlags, omi.BEHRAMFTrop, omi.Row);
end

if strcmpi(return_mode, 'weight')
    omi.(weight_field)(bad_pix) = 0;
    varargout{1} = omi;
elseif strcmpi(return_mode, 'logical')
    varargout{1} = bad_pix;
end

% If we added VcdQualityFlags as a hack to make this function work with
% older BEHR data, remove it now so that we return a structure with the
% same fields as was given.
if remove_temp_flag_field
    omi = rmfield(omi,'VcdQualityFlags');
end

end

function bad_pix = reject_by_behr_flags(behr_flags, reject_bit)
% This is a fix to handle NaNs showing up in the flags, NaNs cause bitand
% to error, and we want to reject them anyway, so just replace NaNs with a
% value that will definitely be rejected
rej_num = bitset(0, reject_bit);
behr_flags(isnan(behr_flags)) = rej_num;
bad_pix = bitand(behr_flags, rej_num)>0;
end

function bad_pix = reject_by_details(details, cloud_frac, vcd_flags, xtrack_flags, behr_amf, rows)

if ~isfield(details, 'rows')
    details.rows = [];
end
if ~isfield(details, 'szalim')
    % not currently implemented since I didn't grid SZA 
    details.szalim = 180;
end

bad_pix = false(size(cloud_frac));
bad_pix = bad_pix | mod(vcd_flags,2) ~= 0;
bad_pix = bad_pix | cloud_frac > details.cloud_frac;

% As of 30 Aug 2017, the PSM OMI structure does not include date. This will
% need to be rectified in the future. For now, just pass 0 as the date.
bad_pix = bad_pix | omi_rowanomaly(xtrack_flags, rows, 0, details.row_anom_mode);

if details.check_behr_amf
    bad_pix = bad_pix | isnan(behr_amf) | behr_amf <= behr_min_amf_val;
end

if ~isempty(details.rows)
    bad_pix = bad_pix | rows < min(details.rows) | rows > max(details.rows);
end


end

