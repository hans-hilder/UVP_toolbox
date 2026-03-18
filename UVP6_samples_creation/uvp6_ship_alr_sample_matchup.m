%% MATCHUP GRID — B-best matching (A can match many), filter B by sampletype, export CSV
% For each B, pick its single best A (min time diff, then min distance) within global thresholds.
% A can participate in multiple matches. B is matched at most once (its best).
% Heatmap counts these B-best matches cumulatively (≤ time, ≤ distance).
% CSV includes FULL profileid from each file and platform labels.

%% -------------------- USER SETTINGS --------------------
fileA = 'uvp6_header_sn000125hf_20240526_dy180.txt';
fileB = 'uvp6_header_sn000227lp_20240807_dy180_biocarbon1_alr4.txt';

% Give your platforms descriptive names for output and plot titles
platformA = 'Ship CTD';
platformB = 'ALR004';

% Time & distance bin edges for the heatmap (thresholds are "≤ bin")
timeBinsHours = [1 6 24 48 72 144];
distBinsKm    = [1 5 10 25 50 100];

% Column names in your files (must match header row)
latCol      = 'latitude';
lonCol      = 'longitude';
timeCol     = 'sampledatetime';
sampIDCol   = 'stationid';
samptypeCol = 'sampletype';
profileCol  = 'profileid';   % we will export this as-is (full string)

% Time format in files
timeFormat = 'yyyyMMdd-HHmmss';

% Filter which sampletype to USE from dataset B only (case-insensitive)
sampletypeFilterB = "d";  % keep rows in B with sampletype == 'd'

% Global maximum thresholds that define eligibility for a match at all
globalMaxHours = max(timeBinsHours);
globalMaxKm    = max(distBinsKm);

% Export threshold for the CSV (e.g., list all matches within 24h AND 10km)
exportMaxHours = 24;
exportMaxKm    = 10;
outCSV = 'best_matches_within_threshold.csv';
%% -------------------------------------------------------

%% Read & clean
A = local_read_metadata(fileA, latCol, lonCol, timeCol, sampIDCol, samptypeCol, profileCol, timeFormat);
B = local_read_metadata(fileB, latCol, lonCol, timeCol, sampIDCol, samptypeCol, profileCol, timeFormat);
if isempty(A) || isempty(B)
    error('After cleaning, one of the files is empty. Check inputs and headers.');
end

% Filter ONLY B by sampletype (case-insensitive)
B = B( lower(B.(samptypeCol)) == lower(sampletypeFilterB), : );
if isempty(B)
    error('After sampletype filtering, B is empty. Check sampletypeFilterB.');
end

%% Pairwise time differences (hours) and haversine distances (km)
dtHours = abs(hours(A.(timeCol) - B.(timeCol).'));   % nA x nB

% Vectorized haversine (broadcasting)
R = 6371.0088; % km
phi1 = deg2rad(A.(latCol));         lam1 = deg2rad(A.(lonCol));
phi2 = deg2rad(B.(latCol)).';       lam2 = deg2rad(B.(lonCol)).';
dphi = phi2 - phi1;
dlam = lam2 - lam1;
a = sin(dphi/2).^2 + cos(phi1).*cos(phi2).*sin(dlam/2).^2;
c = 2*asin(sqrt(a));
distKm = R * c;                      % nA x nB

%% For each B, choose its single BEST A within global thresholds
[nA, nB] = size(dtHours);
eligible = (dtHours <= globalMaxHours) & (distKm <= globalMaxKm);
bestA_for_B = zeros(nB,1);      % 0 if none
bestDT_for_B = nan(nB,1);
bestDS_for_B = nan(nB,1);

for b = 1:nB
    idxA = find(eligible(:,b));
    if isempty(idxA), continue; end
    % Lexicographic: smallest time diff, then smallest distance
    dtb = dtHours(idxA,b);
    dsb = distKm(idxA,b);
    [~, ord] = sortrows([dtb, dsb], [1 2]);
    ia = idxA(ord(1));
    bestA_for_B(b) = ia;
    bestDT_for_B(b) = dtHours(ia,b);
    bestDS_for_B(b) = distKm(ia,b);
end

% Keep only B with a chosen A
hasMatch = bestA_for_B > 0;
selB = find(hasMatch);
selA = bestA_for_B(hasMatch);
selDT = bestDT_for_B(hasMatch);
selDS = bestDS_for_B(hasMatch);

%% Build the heatmap from these B-best matches
nT = numel(timeBinsHours);
nD = numel(distBinsKm);
gridCounts = zeros(nT, nD, 'uint32');

if ~isempty(selDT)
    for i = 1:nT
        tMask = selDT <= timeBinsHours(i);
        for j = 1:nD
            gridCounts(i,j) = sum(tMask & (selDS <= distBinsKm(j)));
        end
    end
end

rowLabels = compose("\x2264%dh", timeBinsHours);  % "≤xh"
colLabels = compose("\x2264%dkm", distBinsKm);    % "≤ykm"

%% Plot heatmap
figure('Color','w'); 
imagesc(gridCounts);
axis tight equal;
set(gca, 'XTick', 1:numel(colLabels), 'XTickLabel', colLabels, ...
         'YTick', 1:numel(rowLabels), 'YTickLabel', rowLabels, ...
         'YDir','normal');
xlabel('Distance bin');
ylabel('Time bin');
title(sprintf('%s → %s best matches (ALR filtered: sampletype=%s)', ...
       platformA, platformB, upper(sampletypeFilterB)));
colorbar;

% Overlay numeric labels
[nR, nC] = size(gridCounts);
for i = 1:nR
    for j = 1:nC
        text(j, i, num2str(gridCounts(i,j)), ...
            'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
            'FontWeight','bold');
    end
end
box on;

%% Export CSV of matches within export threshold (≤ exportMaxHours & ≤ exportMaxKm)
withinExport = (selDT <= exportMaxHours) & (selDS <= exportMaxKm);
expA = selA(withinExport);
expB = selB(withinExport);
expDT = selDT(withinExport);
expDS = selDS(withinExport);

Texp = table;
Texp.Platform_A     = repmat(string(platformA), sum(withinExport), 1);
Texp.A_profileid    = A.(profileCol)(expA);   % full profileid from A
Texp.A_stationid    = A.(sampIDCol)(expA);
Texp.A_sampletype   = A.(samptypeCol)(expA);
Texp.Platform_B     = repmat(string(platformB), sum(withinExport), 1);
Texp.B_profileid    = B.(profileCol)(expB);   % full profileid from B
Texp.B_stationid    = B.(sampIDCol)(expB);
Texp.B_sampletype   = B.(samptypeCol)(expB);
Texp.dt_hours       = expDT;
Texp.dist_km        = expDS;

writetable(Texp, outCSV);
fprintf('Exported %d matches (%s vs %s) to %s (≤ %gh & ≤ %gkm)\n', ...
        height(Texp), platformA, platformB, outCSV, exportMaxHours, exportMaxKm);

%% ====================== HELPERS =========================
function T = local_read_metadata(fname, latCol, lonCol, timeCol, sampIDCol, samptypeCol, profileCol, timeFormat)
    opts = detectImportOptions(fname, 'Delimiter',';');
    opts = setvaropts(opts, opts.VariableNames, 'TreatAsMissing', {'nan','NaN','NAN',''});

    mustHave = {latCol, lonCol, timeCol};
    optional = {sampIDCol, samptypeCol, profileCol};
    for k = 1:numel(mustHave)
        if any(strcmp(opts.VariableNames, mustHave{k}))
            opts = setvartype(opts, mustHave{k}, 'char');
        else
            error('Column "%s" not found in %s. Available columns:\n  %s', ...
                  mustHave{k}, fname, strjoin(opts.VariableNames, ', '));
        end
    end
    for k = 1:numel(optional)
        if any(strcmp(opts.VariableNames, optional{k}))
            opts = setvartype(opts, optional{k}, 'char');
        end
    end

    T = readtable(fname, opts);

    % Version-compatible trim & convert
    T.(latCol)   = str2double(strtrim_if_cell_(T.(latCol)));
    T.(lonCol)   = str2double(strtrim_if_cell_(T.(lonCol)));
    T.(timeCol)  = datetime(string(strtrim_if_cell_(T.(timeCol))), 'InputFormat', timeFormat, 'TimeZone','UTC');

    if ismember(sampIDCol, T.Properties.VariableNames)
        T.(sampIDCol) = string(strtrim_if_cell_(T.(sampIDCol)));
    else
        T.(sampIDCol) = strings(height(T),1);
    end
    if ismember(samptypeCol, T.Properties.VariableNames)
        T.(samptypeCol) = string(strtrim_if_cell_(T.(samptypeCol)));
    else
        T.(samptypeCol) = strings(height(T),1);
    end
    if ismember(profileCol, T.Properties.VariableNames)
        T.(profileCol) = string(strtrim_if_cell_(T.(profileCol)));  % keep FULL profileid
    else
        T.(profileCol) = strings(height(T),1);
    end

    % Keep only rows with valid lat/lon/time
    m = ~isnan(T.(latCol)) & ~isnan(T.(lonCol)) & ~isnat(T.(timeCol));
    cols = {latCol, lonCol, timeCol, sampIDCol, samptypeCol, profileCol};
    T = T(m, cols);
end

function v = strtrim_if_cell_(v)
    if iscell(v), v = strtrim(v); end
end
