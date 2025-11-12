function [ctd_table] = FillCTDtableALR(ctd_table, data_table)
% FillCTDtableALR  Fill a CTD table from ALR exports
%
% Inputs:
%   ctd_table  : NaN table with the UVPapp CTD variable names (created in CreateCTDfile)
%   data_table : table built from ALR NetCDF, expected columns:
%                TIME (double, seconds since 1970-01-01 00:00:00 UTC)
%                DEPTH_SCI (double, m)
%                (optional) SCI_PRESS (double, dbar)
%                (optional) LAT, LON (double)
%
% Output:
%   ctd_table  : populated CTD table with time/depth/pressure/qc flag and ALR extras appended

    n = height(data_table);

    % QC flag default zeros (like the float path)
    if ismember('qc flag', ctd_table.Properties.VariableNames)
        ctd_table.("qc flag") = zeros(n,1);
    end

    % Time: Unix seconds (UTC) -> 'yyyymmddHHMMSSFFF'
    if ismember('TIME', data_table.Properties.VariableNames)
        dt = datetime(1970,1,1,'TimeZone','UTC') + seconds(data_table.TIME);
        dt.TimeZone = 'UTC';
        timeStrings = cellstr(datestr(dt, 'yyyymmddHHMMSSFFF'));
    else
        warning('FillCTDtableALR:MissingTIME', 'TIME column not found; leaving time strings empty.');
        timeStrings = repmat({''}, n, 1);
    end

    % Be robust to exact header spelling
    if ismember('time [yyyymmddhhmmssmmm]', ctd_table.Properties.VariableNames)
        ctd_table.("time [yyyymmddhhmmssmmm]") = timeStrings;
    elseif ismember('time [yyyymmddHHMMSSFFF]', ctd_table.Properties.VariableNames)
        ctd_table.("time [yyyymmddHHMMSSFFF]") = timeStrings;
    else
        error('FillCTDtableALR:TimeHeader', 'CTD table lacks a recognizable time column.');
    end

    % Depth [m] from DEPTH_SCI
    if ismember('DEPTH_SCI', data_table.Properties.VariableNames)
        depthVals = data_table.DEPTH_SCI;
    else
        warning('FillCTDtableALR:MissingDEPTH', 'DEPTH_SCI column not found; setting depth to NaN.');
        depthVals = NaN(n,1);
    end
    if ismember('depth [m]', ctd_table.Properties.VariableNames)
        ctd_table.("depth [m]") = depthVals;
    end

    % Pressure [db] from SCI_PRESS if present; else 1:1 with DEPTH_SCI
    if ismember('SCI_PRESS', data_table.Properties.VariableNames)
        pressVals = data_table.SCI_PRESS;
    else
        pressVals = depthVals; % 1 dbar ≈ 1 m as requested
    end
    if ismember('pressure [db]', ctd_table.Properties.VariableNames)
        ctd_table.("pressure [db]") = pressVals;
    end

    % Temperature/salinity/others remain NaN (as initialized).
    % Append ALR extra columns (like the float path does)
    % Keep TIME as the first column; append everything except TIME.
    extraCols = setdiff(data_table.Properties.VariableNames, {'TIME'}, 'stable');
    ctd_table = [ctd_table, data_table(:, extraCols)];
end
