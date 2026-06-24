function analyze_equalizer_filters(filters_b, filters_a, band_labels, filter_type, fs)
% ANALYZE_EQUALIZER_FILTERS  Full DSP analysis for all equalizer band filters.
%
%   Generates five sets of plots for each band:
%     1. Magnitude response     (freqz)
%     2. Phase response         (freqz)
%     3. Impulse response       (impz)
%     4. Step response          (stepz)
%     5. Pole-zero diagram      (zplane)
%
%   Also prints filter orders to the command window.
%
%   Usage:
%     analyze_equalizer_filters(filters_b, filters_a, band_labels, filter_type, fs)
%
%   Inputs:
%     filters_b   - cell array of numerator coefficient vectors
%     filters_a   - cell array of denominator coefficient vectors (1 for FIR)
%     band_labels - cell array of band name strings
%     filter_type - string: 'FIR' or 'IIR'
%     fs          - sampling frequency in Hz

    num_bands = length(filters_b);
    rows      = ceil(num_bands / 2);

    fprintf('\nGenerating filter analysis plots for %d %s bands...\n', num_bands, filter_type);

    % ------------------------------------------------------------------ %
    %  1. Magnitude Responses
    % ------------------------------------------------------------------ %
    figure('Name', [filter_type ' - Magnitude Responses'], ...
           'Position', [50 50 1200 700]);
    for k = 1:num_bands
        subplot(rows, 2, k);
        [H, f] = freqz(filters_b{k}, filters_a{k}, 2048, fs);
        plot(f, 20*log10(abs(H) + eps), 'b', 'LineWidth', 1.5);
        title(['Band ' num2str(k) ': ' band_labels{k}], 'FontSize', 9);
        xlabel('Frequency (Hz)');
        ylabel('Magnitude (dB)');
        ylim([-90 5]);
        grid on;
    end
    sgtitle([filter_type ' Equalizer Bands — Magnitude Responses'], 'FontWeight', 'bold');

    % ------------------------------------------------------------------ %
    %  2. Phase Responses
    % ------------------------------------------------------------------ %
    figure('Name', [filter_type ' - Phase Responses'], ...
           'Position', [100 50 1200 700]);
    for k = 1:num_bands
        subplot(rows, 2, k);
        [H, f] = freqz(filters_b{k}, filters_a{k}, 2048, fs);
        plot(f, unwrap(angle(H)) * (180/pi), 'r', 'LineWidth', 1.5);
        title(['Band ' num2str(k) ': ' band_labels{k}], 'FontSize', 9);
        xlabel('Frequency (Hz)');
        ylabel('Phase (degrees)');
        grid on;
    end
    sgtitle([filter_type ' Equalizer Bands — Phase Responses'], 'FontWeight', 'bold');

    % ------------------------------------------------------------------ %
    %  3. Impulse Responses
    % ------------------------------------------------------------------ %
    figure('Name', [filter_type ' - Impulse Responses'], ...
           'Position', [150 50 1200 700]);
    for k = 1:num_bands
        subplot(rows, 2, k);
        impz(filters_b{k}, filters_a{k}, 128, fs);
        title(['Band ' num2str(k) ': ' band_labels{k}], 'FontSize', 9);
        grid on;
    end
    sgtitle([filter_type ' Equalizer Bands — Impulse Responses'], 'FontWeight', 'bold');

    % ------------------------------------------------------------------ %
    %  4. Step Responses  (stepz is the proper built-in for this)
    % ------------------------------------------------------------------ %
    figure('Name', [filter_type ' - Step Responses'], ...
           'Position', [200 50 1200 700]);
    for k = 1:num_bands
        subplot(rows, 2, k);
        stepz(filters_b{k}, filters_a{k}, 128, fs);
        title(['Band ' num2str(k) ': ' band_labels{k}], 'FontSize', 9);
        grid on;
    end
    sgtitle([filter_type ' Equalizer Bands — Step Responses'], 'FontWeight', 'bold');

    % ------------------------------------------------------------------ %
    %  5. Pole-Zero Diagrams
    % ------------------------------------------------------------------ %
    figure('Name', [filter_type ' - Pole-Zero Diagrams'], ...
           'Position', [250 50 1200 700]);
    for k = 1:num_bands
        subplot(rows, 2, k);
        zplane(filters_b{k}, filters_a{k});
        title(['Band ' num2str(k) ': ' band_labels{k}], 'FontSize', 9);
        grid on;
    end
    sgtitle([filter_type ' Equalizer Bands — Pole-Zero Diagrams'], 'FontWeight', 'bold');

    % ------------------------------------------------------------------ %
    %  Print filter orders to command window
    % ------------------------------------------------------------------ %
    fprintf('\n--- Filter Orders ---\n');
    for k = 1:num_bands
        fprintf('  Band %d [%-14s]  order = %d\n', k, band_labels{k}, length(filters_b{k})-1);
    end
    fprintf('Filter analysis complete.\n\n');

end
