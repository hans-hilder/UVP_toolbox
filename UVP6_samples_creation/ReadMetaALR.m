function [meta, data_table] = ReadMetaALR(nc_path)
% ReadMetaALR  Read ALR NetCDF to [meta, data_table]
%
% Outputs:
%   meta: Nx4 numeric array (at least columns 1,3,4 are used):
%         col1: datenum time
%         col3: LAT
%         col4: LON
%   data_table: table with variables:
%         TIME (seconds since 1970-01-01 00:00:00 UTC, double)
%         DEPTH_SCI (m, double)
%         (optional) SCI_PRESS (dbar, double) if present
%         (optional) LAT, LON (double)
%
% Notes:
%   - Accepts missing values as NaN.
%   - No resampling/interp.

    % Read variables (TIME, DEPTH_SCI) and optional (SCI_PRESS, LAT, LON)
    TIME = ncread(nc_path, 'TIME');        % seconds since epoch
    DEPTH_SCI = ncread(nc_path, 'DEPTH_SCI');

    % Optionals
    has_press = false; has_lat = false; has_lon = false;
    try
        SCI_PRESS = ncread(nc_path, 'SCI_PRESS');
        has_press = true;
    catch
        SCI_PRESS = [];
    end
    try
        LAT = ncread(nc_path, 'LAT');
        has_lat = true;
    catch
        LAT = [];
    end
    try
        LON = ncread(nc_path, 'LON');
        has_lon = true;
    catch
        LON = [];
    end

    % Column vectors (defensive)
    TIME = TIME(:);
    DEPTH_SCI = DEPTH_SCI(:);
    if has_press, SCI_PRESS = SCI_PRESS(:); end
    if has_lat,   LAT = LAT(:); end
    if has_lon,   LON = LON(:); end

    % data_table
    data_table = table(TIME, DEPTH_SCI, 'VariableNames', {'TIME','DEPTH_SCI'});
    if has_press
        data_table.SCI_PRESS = SCI_PRESS;
    end
    if has_lat
        data_table.LAT = LAT;
    end
    if has_lon
        data_table.LON = LON;
    end

    % meta: datenum time, and lat/lon in cols 3/4 (match existing access pattern)
    tnum = TIME/86400 + datenum(1970,1,1);  % datenum
    % Make sure meta length matches
    n = numel(tnum);
    meta = NaN(n, 4);
    meta(:,1) = tnum;           % time
    if has_lat, meta(:,3) = LAT; end
    if has_lon, meta(:,4) = LON; end
end
