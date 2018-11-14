function [inverted_profiles, scale_factor] = invert_vcd_to_mixing_ratio(vcds, profiles, prof_pres)
% INVERT_VCD_TO_MIXING_RATIOS Calculate mixing ratios from a VCD and profile
%   INVERTED_PROFILES = INVERT_VCD_TO_MIXING_RATIO( VCDS, PROFILES,
%   PROF_PRES) calculates a profile consistent with the shape factor
%   defined by PROFILES and the total VCD defined by VCDS by:
%
%       P' = V .* S
%
%   where P' is the final profile, V the VCD, and S the shape factor
%   vector, computed as:
%
%       S = P / int_p0^ptrop P dp
%
%   P is the input profile. P must be in mixing ratio.
%
%   VCDs may be any size array, but its size must match the size of
%   PROFILES and PROF_PRES after their first dimension. PROF_PRES must be
%   in hPa, VCDs in molec. cm^-2, and PROFILES in mixing ratio (though the
%   scale, i.e. ppm vs ppb should cancel out).

E = JLLErrors;

sz_profiles = size(profiles);
sz_pres = size(prof_pres);

% Can't use isequal(size(vcds), sz_profiles(2:end)) because if the VCDs are
% a vector and the profiles a 2D matrix, then it'll fail ([1 n] != [n]).
if numel(vcds) ~= prod(sz_profiles(2:end))
    E.badinput('The size of VCDS and the size of PROFILES after the first dimension must be the same')
elseif ~isequal(sz_profiles, sz_pres)
    E.badinput('The size of PROFILES and PROF_PRES must be the same')
end

inverted_profiles = nan(size(profiles));
scale_factor = nan(size(vcds));

for i_prof = 1:numel(vcds)
    sf = shape_factor(prof_pres(:,i_prof), profiles(:,i_prof), 'mode', 'mixing ratio');
    inverted_profiles(:,i_prof) = vcds(i_prof) .* sf;
    scale_factor(i_prof) = nanmean(inverted_profiles(:,i_prof) ./ profiles(:,i_prof));
end



end

