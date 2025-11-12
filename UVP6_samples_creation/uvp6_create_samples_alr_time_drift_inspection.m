%%

xx_alr_time_remap = alr_plot_time;
xx_alr_depth_remap = alr_plot_depth;

xx_uvp_time_remap = uvp_time_series{:};
xx_uvp_depth_remap = uvp_depth_series{:};

%%
figure('Color','w');
hold on
scatter(xx_alr_time_remap,xx_alr_depth_remap)
scatter(xx_uvp_time_remap,xx_uvp_depth_remap)
legend({'alr','uvp'})
set(gca,'YDir','reverse');
xlabel('Time');
ylabel('Depth (m)');
title('Raw ALR & UVP depth');

%% SIMPLE TURNING-POINT ALIGNMENT BETWEEN ALR & UVP
%  1) Convert ALR & UVP times to seconds and take overlapping window.
%  2) Smooth depth in time and find turning points (local minima/maxima)
%     that bound dives/ascents of at least minSegmentDepthChange_m.
%  3) Match turning-point times between ALR & UVP (1:1 nearest neighbour).
%  4) Plot histogram of time offsets and zoomed depth snippets.
%  5) Alternative product: refine turning times using vertical-velocity
%     sign changes within a +/- velChangeSearchWindow_s window and
%     overlay those offsets on the histogram.
%
% Assumed inputs in workspace:
%   alr_plot_time      : ALR time vector (datenum, datetime, or seconds)
%   alr_plot_depth     : ALR depth vector (m, positive downward)
%   uvp_time_series    : cell containing UVP time vector
%   uvp_depth_series   : cell containing UVP depth vector
%
%   alrVertVel_mps     : ALR vertical velocity (m/s), same length/order
%                        as alr_plot_time / alr_plot_depth
%   uvpVertVel_mps     : UVP vertical velocity (m/s), same length/order
%                        as uvp_time_series{:} / uvp_depth_series{:}

%% QUICK RAW PLOT (OPTIONAL)
xx_alr_time_remap   = alr_plot_time;
xx_alr_depth_remap  = alr_plot_depth;

xx_uvp_time_remap   = uvp_time_series{:};
xx_uvp_depth_remap  = uvp_depth_series{:};

figure('Color','w');
hold on
scatter(xx_alr_time_remap, xx_alr_depth_remap, 10, 'filled');
scatter(xx_uvp_time_remap, xx_uvp_depth_remap, 10, 'filled');
legend({'ALR','UVP'})
set(gca,'YDir','reverse');
xlabel('Time');
ylabel('Depth (m)');
title('Raw ALR & UVP depth');

%% ------------------------------------------------------------------------
% 0) INPUTS & BASIC SETUP
% -------------------------------------------------------------------------

alrTimeRaw_something    = alr_plot_time(:);
alrDepthRaw_m           = alr_plot_depth(:);

uvpTimeRaw_something    = uvp_time_series{:};
uvpTimeRaw_something    = uvpTimeRaw_something(:);
uvpDepthRaw_m           = uvp_depth_series{:};
uvpDepthRaw_m           = uvpDepthRaw_m(:);

%% ------------------------------------------------------------------------
% 1) USER PARAMETERS
% -------------------------------------------------------------------------

maxPairOffset_s             = 60;      % max |Δt| for matching turning points
windowLength_days           = [];      % [] = use full overlap, or e.g. 5

turningMinProminence_m      = 1.5;     % how "deep" the V must be (m)
turningMinSeparation_s      = 60.0;    % minimum time between turning points (s)
minSegmentDepthChange_m     = 10.0;    % min depth change between successive turning points (m)

depthSmoothingWindow_s      = 20.0;    % total smoothing window on depth (s)

% NEW: zoom window in seconds (instead of number of points)
zoomHalfWindow_s            = 30;      % plot +/- 30 s around ALR turning point

largeOffsetThreshold_s      = 1;       % only zoom pairs with Δt > this (s)

velChangeSearchWindow_s     = 60.0;    % +/- window for velocity sign-change search (s)

% NEW: flag to include/exclude positive Δt in histograms/stats
% true  = use only Δt <= 0 (UVP not later than ALR)
% false = use all matched pairs
restrictToNonPositive       = false;


%% ------------------------------------------------------------------------
% 2) CONVERT TIME TO SECONDS AND FIND OVERLAP
% -------------------------------------------------------------------------

% Convert ALR/UVP times to seconds from a common origin
if isdatetime(alrTimeRaw_something) || isduration(alrTimeRaw_something)
    commonTimeOrigin = min([alrTimeRaw_something(1); uvpTimeRaw_something(1)]);
    alrTime_s = seconds(alrTimeRaw_something - commonTimeOrigin);
    uvpTime_s = seconds(uvpTimeRaw_something - commonTimeOrigin);

elseif isnumeric(alrTimeRaw_something) && isnumeric(uvpTimeRaw_something) && ...
       max(alrTimeRaw_something) > 1e5 && max(uvpTimeRaw_something) > 1e5
    % Likely datenum (days)
    commonTimeOrigin = min([alrTimeRaw_something(1); uvpTimeRaw_something(1)]);
    alrTime_s = (alrTimeRaw_something - commonTimeOrigin) * 86400;
    uvpTime_s = (uvpTimeRaw_something - commonTimeOrigin) * 86400;
else
    % Already in seconds
    alrTime_s = alrTimeRaw_something;
    uvpTime_s = uvpTimeRaw_something;
end

% Sort by time
[alrTime_s, idxA] = sort(alrTime_s);
alrDepth_m        = alrDepthRaw_m(idxA);

[uvpTime_s, idxU] = sort(uvpTime_s);
uvpDepth_m        = uvpDepthRaw_m(idxU);

% Overlapping window
overlapStartTime_s = max(alrTime_s(1),  uvpTime_s(1));
overlapEndTime_s   = min(alrTime_s(end), uvpTime_s(end));

% Optional restriction to a shorter window
if ~isempty(windowLength_days) && ~isnan(windowLength_days)
    requestedEndTime_s = overlapStartTime_s + windowLength_days*24*3600;
    overlapEndTime_s   = min(overlapEndTime_s, requestedEndTime_s);
end

isAlrInWindow = (alrTime_s >= overlapStartTime_s) & (alrTime_s <= overlapEndTime_s);
isUvpInWindow = (uvpTime_s >= overlapStartTime_s) & (uvpTime_s <= overlapEndTime_s);

alrTimeWindow_s   = alrTime_s(isAlrInWindow);
alrDepthWindow_m  = alrDepth_m(isAlrInWindow);

uvpTimeWindow_s   = uvpTime_s(isUvpInWindow);
uvpDepthWindow_m  = uvpDepth_m(isUvpInWindow);

%% ------------------------------------------------------------------------
% 2b) COMPUTE VERTICAL VELOCITY IN THE WINDOW (m/s)
%      Use finite differences; pad with NaN so length matches time.
% -------------------------------------------------------------------------

% Ensure times are strictly increasing (they should be after sort)
% Compute d(depth)/d(time) in m/s
if numel(alrTimeWindow_s) >= 2
    dDepthA = diff(alrDepthWindow_m);
    dTimeA  = diff(alrTimeWindow_s);   % seconds
    alrVelWindow_mps = [NaN; dDepthA ./ dTimeA];
else
    alrVelWindow_mps = nan(size(alrTimeWindow_s));
end

if numel(uvpTimeWindow_s) >= 2
    dDepthU = diff(uvpDepthWindow_m);
    dTimeU  = diff(uvpTimeWindow_s);
    uvpVelWindow_mps = [NaN; dDepthU ./ dTimeU];
else
    uvpVelWindow_mps = nan(size(uvpTimeWindow_s));
end

% NOTE: for the velocity sign-change detection we only care about the sign
% of these velocities, so the exact scaling of dDepth/dTime is not critical.

%% ------------------------------------------------------------------------
% 3) TURNING-POINT DETECTION (LOCAL MINIMA/MAXIMA OF SMOOTHED DEPTH)
%    NOTE: we now keep the turning indices exactly as identified on the
%    smoothed series; no re-indexing using raw-depth minima.
% -------------------------------------------------------------------------

[alrTurningIdx, alrDepthSmooth_m] = ...
    findDepthTurningPoints(alrTimeWindow_s, ...
                           alrDepthWindow_m, ...
                           depthSmoothingWindow_s, ...
                           turningMinProminence_m, ...
                           turningMinSeparation_s, ...
                           minSegmentDepthChange_m);

[uvpTurningIdx, uvpDepthSmooth_m] = ...
    findDepthTurningPoints(uvpTimeWindow_s, ...
                           uvpDepthWindow_m, ...
                           depthSmoothingWindow_s, ...
                           turningMinProminence_m, ...
                           turningMinSeparation_s, ...
                           minSegmentDepthChange_m);

alrTurningTimes_s = alrTimeWindow_s(alrTurningIdx);
uvpTurningTimes_s = uvpTimeWindow_s(uvpTurningIdx);

%% ------------------------------------------------------------------------
% 4) VISUAL CHECK: DEPTH + SMOOTHED + TURNING POINTS
% -------------------------------------------------------------------------

figure('Name','Depth with turning points','Color','w');

subplot(2,1,1);
plot(alrTimeWindow_s, alrDepthWindow_m, 'Color',[0.7 0.7 0.7]); hold on;
plot(alrTimeWindow_s, alrDepthSmooth_m, 'k-');
scatter(alrTurningTimes_s, alrDepthSmooth_m(alrTurningIdx), 40, 'r', 'filled');
set(gca,'YDir','reverse');
xlabel('Time (s)');
ylabel('Depth_{ALR} (m)');
title('ALR: depth (raw + smoothed) & turning points');
legend({'raw depth','smoothed depth','turning point'},'Location','best');
grid on;

subplot(2,1,2);
plot(uvpTimeWindow_s, uvpDepthWindow_m, 'Color',[0.7 0.7 0.7]); hold on;
plot(uvpTimeWindow_s, uvpDepthSmooth_m, 'k-');
scatter(uvpTurningTimes_s, uvpDepthSmooth_m(uvpTurningIdx), 40, 'r', 'filled');
set(gca,'YDir','reverse');
xlabel('Time (s)');
ylabel('Depth_{UVP} (m)');
title('UVP: depth (raw + smoothed) & turning points');
legend({'raw depth','smoothed depth','turning point'},'Location','best');
grid on;

%% ------------------------------------------------------------------------
% 5) MATCH TURNING POINTS AND HISTOGRAM (DEPTH-BASED PRODUCT)
% -------------------------------------------------------------------------

[matchedAlrIdx, matchedUvpIdx, timeDifference_s] = ...
    matchInflectionTimesGreedy(alrTurningTimes_s, ...
                               uvpTurningTimes_s, ...
                               maxPairOffset_s);

fprintf('\nMatched %d turning-point pairs (all signs).\n', numel(timeDifference_s));
fprintf('All pairs: mean dt (UVP - ALR)    = %.3f s\n', mean(timeDifference_s));
fprintf('All pairs: median dt              = %.3f s\n', median(timeDifference_s));

% Decide which pairs to use based on restrictToNonPositive
if restrictToNonPositive
    useMask   = timeDifference_s <= 0;
    maskLabel = 'dt <= 0';
    figName   = 'Histogram of turning-point time differences (dt <= 0)';
else
    useMask   = true(size(timeDifference_s));
    maskLabel = 'all dt';
    figName   = 'Histogram of turning-point time differences (all dt)';
end

timeDifference_used_s = timeDifference_s(useMask);

fprintf('Using %d/%d pairs for histogram/stats (%s).\n', ...
        numel(timeDifference_used_s), numel(timeDifference_s), maskLabel);

figure('Name', figName, 'Color','w');
histogram(timeDifference_used_s, 'BinWidth', 1, ...
          'DisplayName', sprintf('Depth turning points (%s)', maskLabel));
hold on;
xlabel('dt = t_{UVP} - t_{ALR} (s)');
ylabel('Count');
title(['Time differences between matched turning points (', maskLabel, ')']);
grid on;

meanUsed_s   = mean(timeDifference_used_s);
medianUsed_s = median(timeDifference_used_s);
disp(['Selected subset (', maskLabel, '): mean = ', ...
      num2str(meanUsed_s,'%.3f'), ' s, median = ', ...
      num2str(medianUsed_s,'%.3f'), ' s']);

%% ------------------------------------------------------------------------
% 5b) ALTERNATIVE PRODUCT: VELOCITY SIGN-CHANGE REFINEMENT
%       (uses SAME subset as above via useMask)
% -------------------------------------------------------------------------

% Find all velocity sign changes in the windowed series
alrVelChangeTimes_s = findVelocityChangeTimes(alrTimeWindow_s, alrVelWindow_mps);
uvpVelChangeTimes_s = findVelocityChangeTimes(uvpTimeWindow_s, uvpVelWindow_mps);

% For each matched turning-point pair, refine the times to the nearest
% velocity sign-change within +/- velChangeSearchWindow_s
numPairs    = numel(timeDifference_s);
tAlr_vel_s  = nan(numPairs,1);
tUvp_vel_s  = nan(numPairs,1);

for k = 1:numPairs
    % Original depth-based turning times for this pair
    tA = alrTurningTimes_s(matchedAlrIdx(k));
    tU = uvpTurningTimes_s(matchedUvpIdx(k));

    % --- ALR: nearest velocity sign-change around tA ---
    if ~isempty(alrVelChangeTimes_s)
        dA    = alrVelChangeTimes_s - tA;
        maskA = abs(dA) <= velChangeSearchWindow_s;
        if any(maskA)
            [~, idxMinA] = min(abs(dA(maskA)));
            candIdxA      = find(maskA);
            tAlr_vel_s(k) = alrVelChangeTimes_s(candIdxA(idxMinA));
        else
            tAlr_vel_s(k) = NaN;
        end
    end

    % --- UVP: nearest velocity sign-change around tU ---
    if ~isempty(uvpVelChangeTimes_s)
        dU    = uvpVelChangeTimes_s - tU;
        maskU = abs(dU) <= velChangeSearchWindow_s;
        if any(maskU)
            [~, idxMinU] = min(abs(dU(maskU)));
            candIdxU      = find(maskU);
            tUvp_vel_s(k) = uvpVelChangeTimes_s(candIdxU(idxMinU));
        else
            tUvp_vel_s(k) = NaN;
        end
    end
end

% Pairs that actually got a velocity-based refinement
validVelPairs = ~isnan(tAlr_vel_s) & ~isnan(tUvp_vel_s);

% Use the SAME subset as depth hist (useMask) plus valid velocities
velMask              = validVelPairs & useMask;
timeDifference_vel_s = tUvp_vel_s(velMask) - tAlr_vel_s(velMask);

fprintf('Velocity-based refinement (%s): available for %d/%d pairs.\n', ...
        maskLabel, numel(timeDifference_vel_s), numel(timeDifference_s));

% Overlay on the existing histogram
histogram(timeDifference_vel_s, 'BinWidth', 1, ...
          'FaceAlpha', 0.4, ...
          'DisplayName', sprintf('Velocity sign-change refined (%s)', maskLabel));

legend('Location','best');

if ~isempty(timeDifference_vel_s)
    fprintf('Velocity-based (%s): mean dt = %.3f s, median dt = %.3f s\n', ...
        maskLabel, mean(timeDifference_vel_s), median(timeDifference_vel_s));
else
    fprintf('No velocity-based points after applying subset (%s).\n', maskLabel);
end

%% ------------------------------------------------------------------------
% 6) ZOOMED RAW DEPTH PLOTS FOR LARGE POSITIVE OFFSETS (Δt > threshold)
% -------------------------------------------------------------------------

% Only look at matching points that have a positive delta above threshold
largeOffsetMask  = (timeDifference_s > largeOffsetThreshold_s);  % positive AND > threshold
largeOffsetPairs = find(largeOffsetMask);

if isempty(largeOffsetPairs)
    fprintf('No matched turning-point pairs with Δt > %.1f s to plot.\n', ...
            largeOffsetThreshold_s);
else
    fprintf('Plotting %d large-offset pairs (Δt > %.1f s)...\n', ...
            numel(largeOffsetPairs), largeOffsetThreshold_s);
end

for n = 1:numel(largeOffsetPairs)
    pairIdx = largeOffsetPairs(n);

    % Turning-point indices in the windowed arrays
    alrStartIdx = alrTurningIdx(matchedAlrIdx(pairIdx));
    uvpStartIdx = uvpTurningIdx(matchedUvpIdx(pairIdx));

    % Reference time = ALR turning time
    t0 = alrTimeWindow_s(alrStartIdx);

    % Time-based windows: +/- zoomHalfWindow_s for BOTH ALR and UVP
    alrIdxWindow = find( ...
        alrTimeWindow_s >= (t0 - zoomHalfWindow_s) & ...
        alrTimeWindow_s <= (t0 + zoomHalfWindow_s));

    uvpIdxWindow = find( ...
        uvpTimeWindow_s >= (t0 - zoomHalfWindow_s) & ...
        uvpTimeWindow_s <= (t0 + zoomHalfWindow_s));

    % Safety: skip if either window is empty
    if isempty(alrIdxWindow) || isempty(uvpIdxWindow)
        fprintf('Skipping pair %d (insufficient data in +/- %.1f s window).\n', ...
                pairIdx, zoomHalfWindow_s);
        continue;
    end

    % Time relative to ALR turning point
    alrTimeRel_s = alrTimeWindow_s(alrIdxWindow) - t0;
    uvpTimeRel_s = uvpTimeWindow_s(uvpIdxWindow) - t0;

    % Raw depth slices
    alrDepthSlice_m = alrDepthWindow_m(alrIdxWindow);
    uvpDepthSlice_m = uvpDepthWindow_m(uvpIdxWindow);

    % This pair's offset (UVP - ALR) -- guaranteed positive and > threshold
    dt_pair_s = timeDifference_s(pairIdx);

    figure('Name', sprintf('Matched pair %d (\\Delta t = %.2f s)', ...
                           pairIdx, dt_pair_s), ...
           'Color','w');

    plot(alrTimeRel_s, alrDepthSlice_m, 'k.-', 'DisplayName','ALR'); hold on;
    plot(uvpTimeRel_s, uvpDepthSlice_m, 'b.-', 'DisplayName','UVP');

    xline(0,        'r--', 'ALR turning', ...
          'LabelVerticalAlignment','bottom', ...
          'LabelHorizontalAlignment','left');
    xline(dt_pair_s,'m--', 'UVP turning', ...
          'LabelVerticalAlignment','bottom', ...
          'LabelHorizontalAlignment','right');

    set(gca,'YDir','reverse');
    xlabel('Time relative to ALR turning (s)');
    ylabel('Depth (m)');
    title(sprintf(['Zoomed depth around matched turning points ', ...
                   '(pair %d, \\Delta t = %.2f s, window \\pm %.1f s)'], ...
                  pairIdx, dt_pair_s, zoomHalfWindow_s));
    legend('Location','best');
    grid on;
end

%% ========================================================================
% LOCAL FUNCTIONS
% ========================================================================

function [matchedAlrIndices, matchedUvpIndices, timeDifference_s] = ...
    matchInflectionTimesGreedy(alrInflectionTimes_s, uvpInflectionTimes_s, maxPairOffset_s)
%MATCHINFLECTIONTIMESGREEDY
%   One-to-one nearest-neighbour matcher in time.
%
%   For each ALR inflection time, find the UVP inflection time that:
%     - is not already matched
%     - lies within ±maxPairOffset_s
%     - has the smallest |Δt|
%
%   Each UVP inflection is used at most once.

    alrInflectionTimes_s = alrInflectionTimes_s(:);
    uvpInflectionTimes_s = uvpInflectionTimes_s(:);

    numAlr = numel(alrInflectionTimes_s);
    numUvp = numel(uvpInflectionTimes_s);

    maxMatches        = min(numAlr, numUvp);
    matchedAlrIndices = zeros(maxMatches, 1);
    matchedUvpIndices = zeros(maxMatches, 1);
    timeDifference_s  = zeros(maxMatches, 1);

    uvpAlreadyMatched = false(numUvp, 1);
    matchCounter      = 0;

    for idxAlr = 1:numAlr

        currentAlrTime = alrInflectionTimes_s(idxAlr);
        deltaTimes_s   = uvpInflectionTimes_s - currentAlrTime;

        candidateMask = (~uvpAlreadyMatched) & (abs(deltaTimes_s) <= maxPairOffset_s);

        if ~any(candidateMask)
            continue;
        end

        candidateIdx      = find(candidateMask);
        [~, localBestIdx] = min(abs(deltaTimes_s(candidateMask)));
        bestUvpIdx        = candidateIdx(localBestIdx);
        bestDeltaTime_s   = deltaTimes_s(bestUvpIdx);

        matchCounter = matchCounter + 1;
        matchedAlrIndices(matchCounter) = idxAlr;
        matchedUvpIndices(matchCounter) = bestUvpIdx;
        timeDifference_s(matchCounter)  = bestDeltaTime_s;

        uvpAlreadyMatched(bestUvpIdx) = true;
    end

    matchedAlrIndices = matchedAlrIndices(1:matchCounter);
    matchedUvpIndices = matchedUvpIndices(1:matchCounter);
    timeDifference_s  = timeDifference_s(1:matchCounter);
end

function velChangeTimes_s = findVelocityChangeTimes(time_s, vel_mps)
%FINDVELOCITYCHANGETIMES
%   Return times where the sign of vertical velocity changes
%   (upward vs downward motion).

    time_s = time_s(:);
    vel_mps = vel_mps(:);

    if numel(time_s) < 2
        velChangeTimes_s = [];
        return;
    end

    sgn = sign(vel_mps);
    % Treat zeros as missing for sign-change detection
    sgn(sgn == 0) = NaN;

    % Sign change where sgn(i)*sgn(i+1) < 0 (and both non-NaN)
    validPairs = ~isnan(sgn(1:end-1)) & ~isnan(sgn(2:end));
    changeIdx  = find(validPairs & (sgn(1:end-1).*sgn(2:end) < 0));

    % Use mid-point in time between samples as the change time
    velChangeTimes_s = 0.5*(time_s(changeIdx) + time_s(changeIdx+1));
end

function [turnIdxFinal, depthSmooth_m] = ...
    findDepthTurningPoints(time_s, depth_m, smoothWin_s, minProm_m, minSep_s, minSegDelta_m)
%FINDDEPTHTURNINGPOINTS
%   Find local turning points in smoothed depth, then keep only those
%   that bound segments with at least minSegDelta_m depth change.
%
% Inputs:
%   time_s         : time vector (s, increasing)
%   depth_m        : depth vector (m, same size)
%   smoothWin_s    : total smoothing window on depth (seconds)
%   minProm_m      : minimum prominence for a turning point (m)
%   minSep_s       : minimum time separation between turning points (s)
%   minSegDelta_m  : minimum depth change between successive turning
%                    points (m)
%
% Outputs:
%   turnIdxFinal   : indices of accepted turning points (into depth_m)
%   depthSmooth_m  : smoothed depth used for detection

    time_s  = time_s(:);
    depth_m = depth_m(:);

    N = numel(time_s);
    if N < 5
        turnIdxFinal  = [];
        depthSmooth_m = depth_m;
        return;
    end

    % ---- 1) Smooth depth -----------------------------------------------
    dtMed      = median(diff(time_s));                % s
    winSamples = max(5, round(smoothWin_s / dtMed));  % samples

    depthSmooth_m = movmedian(depth_m, winSamples, 'omitnan');
    depthSmooth_m = movmean(depthSmooth_m,  winSamples, 'omitnan');

    % ---- 2) Initial turning-point candidates using findpeaks ----------
    % Note: depth is positive downward; deepest part is a local MAX.
    minDistSamples = max(1, round(minSep_s / dtMed));

    [~, turnIdxCand] = findpeaks(depthSmooth_m, ...
                                 'MinPeakProminence', minProm_m, ...
                                 'MinPeakDistance',   minDistSamples);

    if isempty(turnIdxCand)
        turnIdxFinal = [];
        return;
    end

    % ---- 3) Enforce minimum depth change between successive turning points
    depthAtTurns = depthSmooth_m(turnIdxCand);
    segDelta_m   = abs(diff(depthAtTurns));          % between turns
    bigSegMask   = segDelta_m >= minSegDelta_m;
    bigSegMask   = bigSegMask(:);

    numTurns    = numel(turnIdxCand);
    keepIdxMask = false(numTurns, 1);

    % segment i connects turn i and i+1
    keepIdxMask(1:end-1) = keepIdxMask(1:end-1) | bigSegMask;
    keepIdxMask(2:end)   = keepIdxMask(2:end)   | bigSegMask;

    turnIdxFinal = turnIdxCand(keepIdxMask);
end
