function [  ] = raa_180_tests(  )
%RAA_180_TESTS Check the extra factor of 180 in the RAA calculation
%   In theory, relative azimuth angle (RAA) should just be the difference
%   between the solar and viewing azimuth angles. However, in BEHR there's
%   an extra factor of 180 that essentially makes it the supplement of that
%   angle. Ron suggested that this was related to some unpublished work by
%   Luke Valin that found a in the TOMRAD vs NASA SP RAA definition that it
%   was the supplement, i.e. rather than RAA = 0 being sun and satellite on
%   the same side, RAA = 0 means sun and satellite are on opposite sides.
%   This function was my attempt to reproduce Luke's work, in which he
%   looked at the same point from opposite sides of the OMI detector and
%   found significantly different NO2 columns.
%
%   I've since found that the definition of RAA = 0 => sun and satellite on
%   opposite sides is fairly common in radiative transfer models, so one
%   has to be careful translating between radiative transfer models and
%   physical sun-satellite geometries.

allowed_cities = {'la','denver','chicago','houston','atlanta'};
city = ask_multichoice('Which city to plot?',allowed_cities);
allowed_products = {'behr','sp'};
product = ask_multichoice('Which product to use?', allowed_products);




switch city
    case 'la'
        lonlim = [-121 -116];
        latlim = [32 35];
    case 'denver'
        lonlim = [-106 -104];
        latlim = [39 41];
    case 'chicago'
        lonlim = [-89 -87];
        latlim = [41 42.5];
    case 'atlanta'
        lonlim = [-85 -83];
        latlim = [32.5 35];
    case 'houston'
        lonlim = [-96.5 -94.5];
        latlim = [29 31];
end

if strcmp(product,'behr')
    D=load('/Users/Josh/Documents/MATLAB/BEHR/Workspaces/RAA Tests/US All 2005.mat');
elseif strcmp(product,'sp')
    D=load('/Users/Josh/Documents/MATLAB/BEHR/Workspaces/RAA Tests/US OMNO2 Jul 2005.mat');
end
LON = D.LON;
LAT = D.LAT;
xx = LON(1,:) >= lonlim(1) & LON(1,:) <= lonlim(2);
yy = LAT(:,1) >= latlim(1) & LAT(:,1) <= latlim(2);

if strcmp(product,'behr')
    del_w_180 = D.NO2_w180_r0_29(yy,xx) - D.NO2_w180_r30_59(yy,xx);
    perdel_w_180 = del_w_180 ./ nanmean(cat(3,D.NO2_w180_r0_29(yy,xx),D.NO2_w180_r30_59(yy,xx)),3) * 100;
    del_wo_180 = D.NO2_no180_r0_29(yy,xx) - D.NO2_no180_r30_59(yy,xx);
    perdel_wo_180 = del_wo_180 ./ nanmean(cat(3,D.NO2_no180_r0_29(yy,xx),D.NO2_no180_r30_59(yy,xx)),3) * 100;
    
    abslim = max(abs([del_w_180(:); del_wo_180(:)]));
    perlim = max(abs([perdel_w_180(:); perdel_wo_180(:)]));
    
    make_plot(del_w_180, sprintf('%s with 180 - abs diff',city), abslim);
    make_plot(del_wo_180, sprintf('%s without 180 - abs diff',city), abslim);
    make_plot(perdel_w_180, sprintf('%s with 180 - percent diff',city), perlim);
    make_plot(perdel_wo_180, sprintf('%s with 180 - percent diff',city), perlim);
else
    del = D.OMNO2_r0_29(yy,xx) - D.OMNO2_r30_59(yy,xx);
    perdel = del ./ nanmean(cat(3,D.OMNO2_r0_29(yy,xx),D.OMNO2_r30_59(yy,xx)),3) * 100;
    abslim = max(abs(del(:)));
    perlim = max(abs(perdel(:)));
    
    make_plot(del, sprintf('%s OMNO2 - abs diff', city), abslim);
    make_plot(perdel, sprintf('%s OMNO2 - per diff', city), perlim);
end





    function make_plot(del, titlestr, maxlim)
        figure;
        pcolor(LON(yy,xx), LAT(yy,xx), del);
        shading flat;
        cb = colorbar;
        caxis([-maxlim, maxlim]);
        title(titlestr);
    end

end

