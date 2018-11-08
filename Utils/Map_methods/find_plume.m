function [ in_plume, edge_pixels ] = find_plume( matrix_in, matrix_lon, matrix_lat, threshold, center_lon, center_lat )
% FIND_PLUME Find pixels that in a plume that exceed a threshold.
%   Currently, FIND_PLUME is just aliased to FLOODFILL (in the
%   Matlab-Gen-Utils repo). See the documentation for FLOODFILL.
[in_plume, edge_pixels] = floodfill(matrix_in, matrix_lon, matrix_lat, threshold, center_lon, center_lat);
end

