function behr_uncertainty_base_case()
% Grid cloud pressure and globe terrain height for 2012
% so we can use these files as the base case

dvec = datenum('2012-01-01'):datenum('2012-12-31');
save_dir = fullfile(behr_paths.BEHRUncertSubdir('us'), 'BaseCase');
for i_date = 1:numel(dvec)
    Data = load_behr_file(dvec(i_date), 'daily', 'us');
    OMI = psm_wrapper(Data, Data(1).Grid, 'only_cvm', true, 'extra_cvm_fields', {'CloudPressure', 'GLOBETerrainHeight'});
    savename = fullfile(save_dir, behr_filename(dvec(i_date), 'daily', 'us'));
    fprintf('Saving as %s\n', savename);
    save(savename, 'Data', 'OMI');
end

end
