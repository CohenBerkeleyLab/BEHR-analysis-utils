function [ apri_surf_cell ] = behr_apriori_surface( Data, apri_field )
%BEHR_APRIORI_SURFACE Finds the surface a priori bins
%   APRIORI_SURFACE = BEHR_APRIORI_SURFACE( DATA ) returns the first
%   non-NaN value in each a priori profile in the field BEHRNO2apriori of
%   structure Data. Assumes that the profiles are along the first dimension
%   of that array. If Data is scalar, APRIORI_SURFACE is a matrix. If Data
%   is not scalar, APRIORI_SURFACE is a cell array the same size as Data,
%   with the a priori surface concentrations for each swath in the
%   corresponding element of the cell array.
%
%   APRIORI_SURFACE = BEHR_APRIORI_SURFACE( DATA, APRI_FIELD ) will use the
%   field given by APRI_FIELD instead of BEHRNO2apriori.
%
%   APRIORI_SURFACE = BEHR_APRIORI_SURFACE( APRIORI_ARRAY ) will operate
%   given the 3D array of apriori profiles directly. This requires that the
%   array be organized as it is in the Data structure, that the vertical
%   dimension is first, i.e. APRIORI_ARRAY(:,i) will provide the i-th
%   profile.

if ~exist('apri_field','var')
    apri_field = 'BEHRNO2apriori';
end

if isstruct(Data)
    n_swaths = numel(Data);
    apri_surf_cell = cell(size(Data));
elseif isnumeric(Data)
    n_swaths = 1;
    apri_surf_cell = cell(1);
end


for d=1:n_swaths
    if isstruct(Data)
        no2_apriori = Data(d).(apri_field);
    else
        no2_apriori = Data;
    end
    
    apri_sz = size(no2_apriori);
    apri_surf = nan(apri_sz(2:end));
    
    for a=1:numel(apri_surf)
        no2_slice = no2_apriori(:,a);
        i = find(~isnan(no2_slice),1,'first');
        if ~isempty(i)
            apri_surf(a) = no2_slice(i);
        end
    end
    apri_surf_cell{d} = apri_surf;
end

if numel(apri_surf_cell) == 1
    apri_surf_cell = apri_surf_cell{1};
end

end

