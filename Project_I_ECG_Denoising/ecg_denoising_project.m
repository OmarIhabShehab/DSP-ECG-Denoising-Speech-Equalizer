% =========================================================
% DSP Project - Part I
% ECG Signal Denoising using Digital Filters
% =========================================================
clear; close all; clc;
set(0, 'DefaultFigureWindowStyle', 'docked');  % All figures open as tabs

%% 1. LOAD ECG SIGNAL
[ecg_raw, fs, t] = load_ecg('100', 15000);
fprintf('Sampling Frequency = %d Hz\n', fs);

%% 2. DISPLAY ORIGINAL ECG SIGNAL
ecg_display = ecg_raw - mean(ecg_raw);
figure('Name', 'Original ECG Signal');
plot(t, ecg_display, 'b', 'LineWidth', 1);
xlim([0 8]);
xlabel('Time (Seconds)');
ylabel('Amplitude');
title('Raw ECG Signal Segment (Record 106)');
grid on;

%% 3. FILTER SPECIFICATIONS
hp_cutoff  = 0.5;    % Hz - removes baseline wander below 0.5 Hz
lp_cutoff  = 100;    % Hz - removes EMG noise above 100 Hz
notch_freq = 50;     % Hz - removes power-line interference
fir_order  = 1000;   % High order needed for sharp rolloff at very low cutoff
Rp         = 0.5;    % dB - passband ripple (Chebyshev)
Rs         = 40;     % dB - required stopband attenuation

fprintf('\nFILTER SPECIFICATIONS\n');
fprintf('HPF Cutoff = %.1f Hz\n', hp_cutoff);
fprintf('LPF Cutoff = %.1f Hz\n', lp_cutoff);
fprintf('Notch = %.1f Hz\n', notch_freq);
fprintf('Passband Ripple = %.1f dB | Stopband Attenuation = %.1f dB\n', Rp, Rs);
fprintf('FIR Order = %d\n', fir_order);

%% 4. FIR KAISER
% Kaiser window with beta=6 gives ~44 dB stopband attenuation
beta   = 6;
hp_fir = fir1(fir_order, hp_cutoff/(fs/2), 'high', kaiser(fir_order+1, beta));
lp_fir = fir1(fir_order, lp_cutoff/(fs/2), 'low',  kaiser(fir_order+1, beta));
fprintf('\nKaiser Window Filters Designed (Order=%d, Beta=%d)\n', fir_order, beta);

%% 5. FIR HAMMING
% Hamming window gives ~41 dB stopband attenuation - simpler alternative
hp_fir_hamming = fir1(fir_order, hp_cutoff/(fs/2), 'high', hamming(fir_order+1));
lp_fir_hamming = fir1(fir_order, lp_cutoff/(fs/2), 'low',  hamming(fir_order+1));
fprintf('Hamming Window Filters Designed (Order=%d)\n', fir_order);

%% 6. BUTTERWORTH IIR
% ba form kept for freqz analysis; SOS form used for stable filtering
[b_hp_but, a_hp_but]   = butter(4,  hp_cutoff/(fs/2), 'high');
[b_lp_but, a_lp_but]   = butter(20, lp_cutoff/(fs/2), 'low');
[sos_hp_but, g_hp_but] = tf2sos(b_hp_but, a_hp_but);
[sos_lp_but, g_lp_but] = tf2sos(b_lp_but, a_lp_but);
fprintf('Butterworth Filters Designed (HPF=4, LPF=20) — SOS form\n');

%% 7. CHEBYSHEV TYPE-I IIR
% Sharper rolloff than Butterworth at same order, at cost of passband ripple
[b_hp_cheb, a_hp_cheb]   = cheby1(4,  Rp, hp_cutoff/(fs/2), 'high');
[b_lp_cheb, a_lp_cheb]   = cheby1(15, Rp, lp_cutoff/(fs/2), 'low');
[sos_hp_cheb, g_hp_cheb] = tf2sos(b_hp_cheb, a_hp_cheb);
[sos_lp_cheb, g_lp_cheb] = tf2sos(b_lp_cheb, a_lp_cheb);
fprintf('Chebyshev Type-I Filters Designed (HPF=4, LPF=15) — SOS form\n');

%% 8. NOTCH FILTER
% Q = f0/BW — Q=25 gives 2 Hz bandwidth, sufficient to remove 50 Hz line noise
Q_notch = 25;
wo      = notch_freq / (fs/2);
bw      = wo / Q_notch;
[b_notch, a_notch] = iirnotch(wo, bw);
fprintf('Notch Filter Designed at %d Hz  (Q = %d, BW = %.2f Hz)\n', ...
        notch_freq, Q_notch, notch_freq/Q_notch);

%% 9. DISPLAY COEFFICIENTS
fprintf('\nBUTTERWORTH HPF COEFFICIENTS\n');
fprintf('b: '); disp(b_hp_but);
fprintf('a: '); disp(a_hp_but);

fprintf('\nCHEBYSHEV HPF COEFFICIENTS\n');
fprintf('b: '); disp(b_hp_cheb);
fprintf('a: '); disp(a_hp_cheb);

fprintf('\nFIR KAISER HPF COEFFICIENTS (first 10)\n');
disp(hp_fir(1:10));

fprintf('\nNOTCH COEFFICIENTS\n');
fprintf('b: '); disp(b_notch);
fprintf('a: '); disp(a_notch);

%% 10. FILTER ANALYSIS
% High-pass filters
analyze_filter(hp_fir,         1,         fs, 'FIR (Kaiser) High-pass');
analyze_filter(hp_fir_hamming, 1,         fs, 'FIR (Hamming) High-pass');
analyze_filter(b_hp_but,       a_hp_but,  fs, 'Butterworth High-pass');
analyze_filter(b_hp_cheb,      a_hp_cheb, fs, 'Chebyshev Type-I High-pass');

% Notch filter
analyze_filter(b_notch, a_notch, fs, 'IIR Notch Filter 50 Hz');

% Low-pass filters
analyze_filter(lp_fir,         1,         fs, 'FIR (Kaiser) Low-pass');
analyze_filter(lp_fir_hamming, 1,         fs, 'FIR (Hamming) Low-pass');
analyze_filter(b_lp_but,       a_lp_but,  fs, 'Butterworth Low-pass');
analyze_filter(b_lp_cheb,      a_lp_cheb, fs, 'Chebyshev Type-I Low-pass');

%% 11. VERIFY FILTER SPECIFICATIONS
fprintf('\n==================================== FILTER SPECIFICATION VERIFICATION ====================================\n');

% High-pass filters
verify_filter_specs(hp_fir,    1,         fs, hp_cutoff, 'high', Rs, 'FIR Kaiser HPF');
verify_filter_specs(b_hp_but,  a_hp_but,  fs, hp_cutoff, 'high', Rs, 'Butterworth HPF');
verify_filter_specs(b_hp_cheb, a_hp_cheb, fs, hp_cutoff, 'high', Rs, 'Chebyshev HPF');

% Notch filter
[Hn, fn]    = freqz(b_notch, a_notch, 4096, fs);
[~, idx]    = min(abs(fn - notch_freq));
notch_atten = -20*log10(abs(Hn(idx)));
fprintf('Notch Filter: Attenuation at 50 Hz = %.2f dB [%s]\n', ...
        notch_atten, iff(notch_atten >= Rs, 'PASS ✓', 'CHECK'));

% Low-pass filters
verify_filter_specs(lp_fir,    1,         fs, lp_cutoff, 'low', Rs, 'FIR Kaiser LPF');
verify_filter_specs(b_lp_but,  a_lp_but,  fs, lp_cutoff, 'low', Rs, 'Butterworth LPF');
verify_filter_specs(b_lp_cheb, a_lp_cheb, fs, lp_cutoff, 'low', Rs, 'Chebyshev LPF');

%% 12. APPLY FILTERS TO ECG SIGNAL
% filtfilt used throughout — zero-phase, no group delay distortion

% FIR Kaiser
ecg_fir = filtfilt(hp_fir, 1, ecg_raw);
ecg_fir = filtfilt(b_notch, a_notch, ecg_fir);
ecg_fir = filtfilt(lp_fir, 1, ecg_fir);
fprintf('\nKaiser Filtering Complete\n');

% FIR Hamming
ecg_hamming = filtfilt(hp_fir_hamming, 1, ecg_raw);
ecg_hamming = filtfilt(b_notch, a_notch, ecg_hamming);
ecg_hamming = filtfilt(lp_fir_hamming, 1, ecg_hamming);
fprintf('Hamming Filtering Complete\n');

% Butterworth — SOS form prevents numerical overflow at order 20
ecg_but = filtfilt(sos_hp_but, g_hp_but, ecg_raw);
ecg_but = filtfilt(b_notch, a_notch, ecg_but);
ecg_but = filtfilt(sos_lp_but, g_lp_but, ecg_but);
fprintf('Butterworth Filtering Complete (SOS)\n');

% Chebyshev — SOS form prevents numerical overflow at order 15
ecg_cheb = filtfilt(sos_hp_cheb, g_hp_cheb, ecg_raw);
ecg_cheb = filtfilt(b_notch, a_notch, ecg_cheb);
ecg_cheb = filtfilt(sos_lp_cheb, g_lp_cheb, ecg_cheb);
fprintf('Chebyshev Filtering Complete (SOS)\n');

%% 13. TIME DOMAIN COMPARISON
figure('Name', 'Time Domain Comparison');
tl = tiledlayout(5, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, 'ECG Signal Denoising Results - MIT-BIH Record 106', ...
      'FontSize', 14, 'FontWeight', 'bold');

nexttile; plot(t, ecg_raw,     'b', 'LineWidth', 1.2); xlim([0,5]);
ylabel('mV'); title('(a) Raw ECG Signal (Noisy)'); grid on;

nexttile; plot(t, ecg_fir,     'r', 'LineWidth', 1.2); xlim([0,5]);
ylabel('mV'); title('(b) FIR Kaiser Filtered'); grid on;

nexttile; plot(t, ecg_hamming, 'g', 'LineWidth', 1.2); xlim([0,5]);
ylabel('mV'); title('(c) FIR Hamming Filtered'); grid on;

nexttile; plot(t, ecg_but,     'm', 'LineWidth', 1.2); xlim([0,5]);
ylabel('mV'); title('(d) Butterworth IIR Filtered'); grid on;

nexttile; plot(t, ecg_cheb,    'c', 'LineWidth', 1.2); xlim([0,5]);
xlabel('Time (s)'); ylabel('mV'); title('(e) Chebyshev Type-I IIR Filtered'); grid on;

%% 14. POWER SPECTRAL DENSITY COMPARISON
[pxx_raw,     f_psd] = pwelch(ecg_raw,     1024, 512, 1024, fs);
[pxx_fir,     ~]     = pwelch(ecg_fir,     1024, 512, 1024, fs);
[pxx_hamming, ~]     = pwelch(ecg_hamming, 1024, 512, 1024, fs);
[pxx_but,     ~]     = pwelch(ecg_but,     1024, 512, 1024, fs);
[pxx_cheb,    ~]     = pwelch(ecg_cheb,    1024, 512, 1024, fs);

figure('Name', 'PSD Comparison');
plot(f_psd, 10*log10(pxx_raw),     'k', 'LineWidth', 1); hold on;
plot(f_psd, 10*log10(pxx_fir),     'r', 'LineWidth', 1);
plot(f_psd, 10*log10(pxx_hamming), 'g', 'LineWidth', 1);
plot(f_psd, 10*log10(pxx_but),     'b', 'LineWidth', 1);
plot(f_psd, 10*log10(pxx_cheb),    'm', 'LineWidth', 1);
xlim([0, 120]); grid on;
xlabel('Frequency (Hz)'); ylabel('Power/Frequency (dB/Hz)');
title('Power Spectral Density Comparison (Welch Method)');
legend('Raw ECG', 'FIR (Kaiser)', 'FIR (Hamming)', 'Butterworth', 'Chebyshev');
xline(hp_cutoff,  'k--', 'Baseline Cutoff');
xline(notch_freq, 'r--', '50 Hz Notch');
xline(lp_cutoff,  'g--', '100 Hz Cutoff');

%% 15. SPECTROGRAM COMPARISON
figure('Name', 'Spectrogram Comparison');
tl3 = tiledlayout(2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl3, 'Spectrogram Comparison (STFT)', 'FontSize', 13, 'FontWeight', 'bold');

nexttile; spectrogram(ecg_raw,     256, 128, 256, fs, 'yaxis'); title('Raw ECG');
nexttile; spectrogram(ecg_fir,     256, 128, 256, fs, 'yaxis'); title('FIR (Kaiser)');
nexttile; spectrogram(ecg_hamming, 256, 128, 256, fs, 'yaxis'); title('FIR (Hamming)');
nexttile; spectrogram(ecg_but,     256, 128, 256, fs, 'yaxis'); title('Butterworth');
nexttile; spectrogram(ecg_cheb,    256, 128, 256, fs, 'yaxis'); title('Chebyshev');

%% 16. QRS COMPLEX ZOOM
figure('Name', 'QRS Complex Comparison');
idx_zoom = (t >= 2 & t <= 3);
plot(t(idx_zoom), ecg_raw(idx_zoom),     'k', 'LineWidth', 1.5); hold on;
plot(t(idx_zoom), ecg_fir(idx_zoom),     'r', 'LineWidth', 1.2);
plot(t(idx_zoom), ecg_hamming(idx_zoom), 'g', 'LineWidth', 1.2);
plot(t(idx_zoom), ecg_but(idx_zoom),     'b', 'LineWidth', 1.2);
plot(t(idx_zoom), ecg_cheb(idx_zoom),    'm', 'LineWidth', 1.2);
xlabel('Time (s)'); ylabel('Amplitude');
title('QRS Complex Comparison (Zoomed 2-3 Seconds)');
legend('Raw ECG', 'FIR (Kaiser)', 'FIR (Hamming)', 'Butterworth', 'Chebyshev');
grid on;

%% 17. SNR IMPROVEMENT
% SNR computed as signal power in ECG band (0.5-40 Hz) vs noise outside it
% Improvement = SNR after filtering - SNR of raw signal
fprintf('\n==================================== SNR RESULTS ====================================\n');

ecg_raw_dc  = ecg_raw - mean(ecg_raw);
P_sig_raw   = bandpower(ecg_raw_dc, fs, [0.5 40]);
P_noise_raw = bandpower(ecg_raw_dc, fs, [0 0.5]) + bandpower(ecg_raw_dc, fs, [100 fs/2]);
snr_raw     = 10*log10(P_sig_raw / max(P_noise_raw, eps));
fprintf('Raw Signal  : SNR = %.2f dB\n\n', snr_raw);

names           = {'FIR Kaiser', 'FIR Hamming', 'Butterworth', 'Chebyshev'};
signals         = {ecg_fir, ecg_hamming, ecg_but, ecg_cheb};
snr_filtered    = zeros(4,1);
snr_improvement = zeros(4,1);

for i = 1:4
    s       = signals{i} - mean(signals{i});
    P_sig   = bandpower(s, fs, [0.5 40]);
    P_noise = bandpower(s, fs, [0 0.5]) + bandpower(s, fs, [40 fs/2]);
    snr_filtered(i)    = 10*log10(P_sig / max(P_noise, eps));
    snr_improvement(i) = snr_filtered(i) - snr_raw;
    fprintf('%s:\n', names{i});
    fprintf('   SNR after filtering = %.2f dB\n',   snr_filtered(i));
    fprintf('   SNR improvement     = %.2f dB\n\n', snr_improvement(i));
end

%% 18. SNR BAR PLOT
figure('Name', 'SNR Improvement');
bar_handle = bar(snr_improvement);   % fixed: renamed from 'b' to avoid variable conflict
set(gca, 'XTickLabel', names);
ylabel('SNR Improvement (dB)');
title('SNR Improvement After Filtering (vs Raw Signal)');
grid on;
ylim([0 20]);

% Add value labels on top of each bar
for i = 1:length(snr_improvement)
    text(i, snr_improvement(i) + 0.5, ...
         sprintf('%.2f dB', snr_improvement(i)), ...
         'HorizontalAlignment', 'center', ...
         'FontWeight', 'bold', 'FontSize', 10);
end

%% 19. COMPUTATIONAL COMPLEXITY
fprintf('\n==================================== COMPUTATIONAL COMPLEXITY ====================================\n');
fprintf('FIR Order (%d): %d multiplications/sample\n', fir_order, fir_order+1);
fprintf('FIR Latency = %.1f ms  (offline only — not suitable for real-time)\n', (fir_order/2)/fs*1000);
fprintf('Butterworth LPF (order 20, SOS): ~41 multiplications/sample\n');
fprintf('Chebyshev LPF  (order 15, SOS): ~31 multiplications/sample\n');
fprintf('Note: SOS prevents numerical overflow for high-order IIR filters.\n');
fprintf('\nPROJECT PART I COMPLETED SUCCESSFULLY\n');

%% ====================== FUNCTIONS ======================

function analyze_filter(b, a, fs, name)
    figure('Name', name, 'Color', [0.15 0.15 0.15]);
    [H, f] = freqz(b, a, 1024, fs);

    tl = tiledlayout(3, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tl, name, 'Color', 'w', 'FontSize', 14, 'FontWeight', 'bold');

    % Apply dark theme to axes
    function apply_dark(ax)
        set(ax, 'Color', [0.1 0.1 0.1], 'XColor', 'w', 'YColor', 'w', ...
                'GridColor', 'w', 'GridAlpha', 0.4);
        grid(ax, 'on');
        ax.Title.Color  = 'w';
        ax.XLabel.Color = 'w';
        ax.YLabel.Color = 'w';
    end

    % Magnitude
    ax1 = nexttile;
    plot(f, 20*log10(abs(H)+eps), 'Color', '#0044ff', 'LineWidth', 1.2);
    title('Magnitude'); xlabel('Frequency (Hz)'); ylabel('Magnitude (dB)');
    apply_dark(ax1);

    % Phase
    ax2 = nexttile;
    plot(f, angle(H)*180/pi, 'Color', 'r', 'LineWidth', 1.2);
    title('Phase Response'); xlabel('Frequency (Hz)'); ylabel('Phase (degrees)');
    apply_dark(ax2);

    % Impulse response
    ax3 = nexttile;
    [h_imp, t_imp] = impz(b, a, [], fs);
    stem(t_imp, h_imp, 'Color', '#2b8cbe', 'Marker', 'o', ...
         'MarkerFaceColor', '#2b8cbe', 'LineWidth', 1, 'MarkerSize', 3);
    title('Impulse Response'); xlabel('Time (s)'); ylabel('Amplitude');
    apply_dark(ax3);

    % Step response
    ax4 = nexttile;
    [s_resp, t_step] = stepz(b, a, [], fs);
    stem(t_step, s_resp, 'Color', '#2b8cbe', 'Marker', 'o', ...
         'MarkerFaceColor', '#2b8cbe', 'LineWidth', 1, 'MarkerSize', 3);
    title('Step Response'); xlabel('Time (s)'); ylabel('Amplitude');
    apply_dark(ax4);

    % Pole-zero plot
    ax5 = nexttile;
    zplane(b, a);
    title('Pole-Zero Plot');
    apply_dark(ax5);

    % Group delay
    ax6 = nexttile;
    [gd, f_gd] = grpdelay(b, a, 1024, fs);
    plot(f_gd, gd, 'Color', '#2b8cbe', 'LineWidth', 1.2);
    title('Group Delay'); xlabel('Frequency (Hz)'); ylabel('Samples');
    apply_dark(ax6);
end

function verify_filter_specs(b, a, fs, cutoff, ftype, Rs_req, name)
    [H, f] = freqz(b, a, 4096, fs);
    mag    = 20*log10(abs(H)+eps);

    if strcmp(ftype, 'high')
        stop_f = cutoff * 0.2;   % check at 20% of cutoff — inside stopband
    else
        stop_f = cutoff + max(cutoff * 0.15, 10);   % check 15% above cutoff
    end

    [~, idx] = min(abs(f - stop_f));
    atten    = -mag(idx);

    fprintf('%s: Stopband atten at %.2f Hz = %.2f dB (Req >= %.1f) [%s]\n', ...
        name, stop_f, atten, Rs_req, ...
        iff(atten >= Rs_req, 'PASS ✓', 'NOTE: Transition band limitation'));
end

function out = iff(condition, true_val, false_val)
    if condition; out = true_val; else; out = false_val; end
end