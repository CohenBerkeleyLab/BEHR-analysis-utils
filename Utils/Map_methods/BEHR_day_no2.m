function [ values, count ] = BEHR_day_no2( OMI, varargin )
%BEHR_DAY_NO2 - handles the weighting of a day's worth of BEHR data

E = JLLErrors;

%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%% INPUT PARSING %%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%

p = inputParser;
p.addOptional('avgfield','BEHRColumnAmountNO2Trop',@ischar)
p.addParameter('weightsfield','Areaweight',@ischar);
p.addParameter('rejectmode', 'detailed');
p.addParameter('clouds', 'omi');
p.addParameter('cloudfraccrit', 0.2);
p.addParameter('rowanomaly', 'XTrackFlags');
p.addParameter('checkamf',true);

p.parse(varargin{:});
pout = p.Results;

avg_field = pout.avgfield;
weights_field = pout.weightsfield;

if ~ischar(avg_field)
    E.badinput('MAPFIELD must be a character array')
elseif ~isfield(OMI, avg_field)
    E.badinput('MAPFIELD must be a field in OMI');
end
if ~ischar(weights_field)
    E.badinput('WEIGHTSFIELD must be a character array')
elseif ~isfield(OMI, weights_field)
    E.badinput('WEIGHTSFIELD must be a field in OMI');
end

if ~ischar(pout.rejectmode)
    % Validation of what values it may have should be done in
    % omi_pixel_reject.
    E.badinput('"rejectmode" must be a string')
else
    reject_mode = pout.rejectmode;
end

% Likewise, these get checked in omi_pixel_reject
reject_details.cloud_type = pout.clouds;
reject_details.cloud_frac = pout.cloudfraccrit;
reject_details.row_anom_mode = pout.rowanomaly;
reject_details.check_behr_amf = pout.checkamf;

values = nan(size(OMI(1).(avg_field)));
weights = nan(size(OMI(1).(avg_field)));
count = zeros(size(OMI(1).(avg_field)));

for a=1:numel(OMI)
    this_swath = omi_pixel_reject(OMI(a), reject_mode, reject_details, 'weight_field', weights_field);
    
    this_swath_values = this_swath.(avg_field);
    this_swath_weights = this_swath.(weights_field);
    values = nansum(cat(3, values, this_swath_values .* this_swath_weights), 3);
    weights = nansum(cat(3, weights, this_swath_weights),3);
    count = count + weights > 0;
end

values = values ./ weights;


end

