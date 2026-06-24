%% =========================================================================
%  Multi-Band Speech Equalizer for Podcast Enhancement
%  DSP Course Project — Part II 
% =========================================================================

clear; close all; clc;
set(0, 'DefaultFigureWindowStyle', 'docked');  % All figures open as tabs

%% ========== USER INPUTS ==========
audio_file   = 'Test1_man.wav';
filter_type  = 'FIR';          % 'FIR' or 'IIR'
iir_subtype  = 'Butterworth';  % 'Butterworth' or 'Chebyshev'
filter_order = 80;
mode         = 'preset';       % 'preset' or 'custom'

gains_dB = [0, 3, 5, 6, 4, 2, 0];

%% ========== LOAD AUDIO ==========
% Generate synthetic signal if file not found
if ~exist(audio_file, 'file')
    fs_orig = 44100;
    t_syn   = (0:fs_orig*3-1)'/fs_orig;
    x = 0.3*sin(2*pi*200*t_syn) + 0.5*sin(2*pi*800*t_syn) + ...
        0.4*sin(2*pi*2000*t_syn) + 0.2*sin(2*pi*5000*t_syn) + ...
        0.1*randn(size(t_syn));
    x = x / max(abs(x));
    audiowrite(audio_file, x, fs_orig);
    fprintf('Synthetic signal generated and saved as "%s".\n', audio_file);
end

[x_orig, fs_orig] = audioread(audio_file);
if size(x_orig,2) > 1
    x_orig = mean(x_orig,2);   % Stereo to mono
end
x_orig = x_orig / max(abs(x_orig));   % Normalize to [-1, 1]
nyq = fs_orig / 2;

fprintf('Loaded : %s\n', audio_file);
fprintf('Fs     : %d Hz\n', fs_orig);
fprintf('Length : %.2f seconds\n\n', length(x_orig)/fs_orig);

%% ========== BAND DEFINITION ==========
if strcmp(mode, 'preset')
    % 7 speech-optimized bands covering full audio range
    band_edges  = [0 100 300 800 2000 5000 10000 20000];
    band_labels = {'0-100','100-300','300-800','800-2k','2k-5k','5k-10k','10k-20k'};

else
    % Interactive custom mode — user defines bands and gains
    fprintf('\n--- CUSTOM MODE ---\n');
    num_bands  = input('Enter number of bands (5-10): ');
    band_edges = input('Enter band edges (start 0, end 20000): ');
    gains_dB   = input('Enter gains in dB: ');
    num_bands  = length(band_edges) - 1;
    band_labels = cell(1, num_bands);
    for k = 1:num_bands
        band_labels{k} = sprintf('%d-%d Hz', band_edges(k), band_edges(k+1));
    end
end

num_bands = length(band_edges) - 1;

%% ========== FILTER DESIGN ==========
filters_b = cell(num_bands, 1);
filters_a = cell(num_bands, 1);
order_iir = 4;
Rp        = 0.5;   % Chebyshev passband ripple in dB

fprintf('Designing filters...\n');
for k = 1:num_bands
    f1 = max(band_edges(k)   / nyq, 0.001);
    f2 = min(band_edges(k+1) / nyq, 0.999);

    if strcmp(filter_type, 'FIR')
        % Blackman window — 74 dB stopband attenuation, no parameter tuning needed
        win = blackman(filter_order+1);
        if k == 1
            b = fir1(filter_order, f2, 'low', win);
        elseif k == num_bands
            b = fir1(filter_order, f1, 'high', win);
        else
            b = fir1(filter_order, [f1 f2], 'bandpass', win);
        end
        a = 1;

    else
        if strcmp(iir_subtype, 'Chebyshev')
            design = @(o,w,t) cheby1(o, Rp, w, t);
        else
            design = @(o,w,t) butter(o, w, t);
        end
        if k == 1
            [b,a] = design(order_iir, f2, 'low');
        elseif k == num_bands
            [b,a] = design(order_iir, f1, 'high');
        else
            [b,a] = design(order_iir, [f1 f2], 'bandpass');
        end
    end

    filters_b{k} = b;
    filters_a{k} = a;
    fprintf('  Band %d [%-12s] order = %d\n', k, band_labels{k}, length(b)-1);
end

%% ========== FILTER ANALYSIS ==========
fprintf('\nGenerating filter analysis plots...\n');
for k = 1:num_bands
    figure('Name', ['Band ' num2str(k) ' - ' band_labels{k}], 'NumberTitle', 'off');

    [H, f] = freqz(filters_b{k}, filters_a{k}, 1024, fs_orig);

    subplot(3,2,1);
    plot(f, 20*log10(abs(H)+eps), 'b', 'LineWidth', 1.2); grid on;
    title(['Magnitude - ' band_labels{k}]);
    xlabel('Frequency (Hz)'); ylabel('Magnitude (dB)');

    subplot(3,2,2);
    plot(f, unwrap(angle(H))*180/pi, 'r', 'LineWidth', 1.2); grid on;
    title('Phase Response');
    xlabel('Frequency (Hz)'); ylabel('Phase (degrees)');

    subplot(3,2,3);
    impz(filters_b{k}, filters_a{k});
    title('Impulse Response');

    subplot(3,2,4);
    stepz(filters_b{k}, filters_a{k});
    title('Step Response');

    subplot(3,2,5);
    zplane(filters_b{k}, filters_a{k});
    title('Pole-Zero Plot');

    subplot(3,2,6);
    grpdelay(filters_b{k}, filters_a{k}, 1024, fs_orig);
    title('Group Delay');

    sgtitle(['Filter Analysis — Band ' num2str(k) ': ' band_labels{k}], ...
            'FontWeight', 'bold');
end

%% ========== APPLY FILTERS + GAINS ==========
fprintf('\nApplying filters and gains...\n');
x_bands  = zeros(length(x_orig), num_bands);
x_gained = zeros(length(x_orig), num_bands);

for k = 1:num_bands
    x_bands(:,k)  = filtfilt(filters_b{k}, filters_a{k}, x_orig);
    gain           = 10^(gains_dB(k)/20);   % Convert dB to linear
    x_gained(:,k) = gain * x_bands(:,k);
    fprintf('  Band %d [%-12s] gain = %+.1f dB\n', k, band_labels{k}, gains_dB(k));
end

% Sum all bands and normalize
x_eq = sum(x_gained, 2);
x_eq = x_eq / (max(abs(x_eq)) + eps);

%% ========== PERFORMANCE METRICS ==========
rms_orig = sqrt(mean(x_orig.^2));
rms_eq   = sqrt(mean(x_eq.^2));
p_change = 10*log10(mean(x_eq.^2) / mean(x_orig.^2));
rho      = corrcoef(x_orig, x_eq);

fprintf('\n=== PERFORMANCE METRICS ===\n');
fprintf('RMS  — Original  : %.4f\n', rms_orig);
fprintf('RMS  — Equalized : %.4f\n', rms_eq);
fprintf('Power Change     : %+.2f dB\n', p_change);
fprintf('Correlation      : %.4f\n', rho(1,2));

%% ========== TIME DOMAIN COMPARISON ==========
t_axis  = (0:length(x_orig)-1)' / fs_orig;
seg_end = min(round(0.05*fs_orig), length(x_orig));   % First 50 ms

figure('Name', 'Time Domain Comparison', 'NumberTitle', 'off');
subplot(2,1,1);
plot(t_axis(1:seg_end), x_orig(1:seg_end), 'b', 'LineWidth', 1.2);
title('Original Signal — First 50 ms');
xlabel('Time (s)'); ylabel('Amplitude'); grid on;

subplot(2,1,2);
plot(t_axis(1:seg_end), x_eq(1:seg_end), 'r', 'LineWidth', 1.2);
title('Equalized Signal — First 50 ms');
xlabel('Time (s)'); ylabel('Amplitude'); grid on;

sgtitle('Time Domain Waveform Comparison', 'FontWeight', 'bold');

%% ========== PSD COMPARISON ==========
figure('Name', 'PSD Comparison', 'NumberTitle', 'off');
pwelch(x_orig, 1024, 512, 1024, fs_orig); hold on;
pwelch(x_eq,   1024, 512, 1024, fs_orig);
legend('Original', 'Equalized', 'Location', 'best');
title('Power Spectral Density — Welch Method');
xlabel('Frequency (Hz)'); ylabel('Power/Frequency (dB/Hz)'); grid on;

%% ================= SPECTROGRAM & DIFFERENCE ANALYSIS =================
figure('Name', 'Spectrogram Analysis & Difference', 'NumberTitle', 'off');

subplot(3,1,1);
spectrogram(x_orig, 512, 256, 512, fs_orig, 'yaxis');
title('1. Original Spectrogram');

subplot(3,1,2);
spectrogram(x_eq, 512, 256, 512, fs_orig, 'yaxis');
title('2. Equalized Spectrogram');

subplot(3,1,3);
[S_orig, F_sp, T_sp] = spectrogram(x_orig, 512, 256, 512, fs_orig);
[S_eq, ~, ~]         = spectrogram(x_eq,   512, 256, 512, fs_orig);

Mag_diff = 20*log10(abs(S_eq) + eps) - 20*log10(abs(S_orig) + eps);

imagesc(T_sp, F_sp/1000, Mag_diff);
axis xy; colorbar; colormap(gca, jet);
title('3. Spectrogram Difference (Equalized - Original) in dB');
xlabel('Time (s)'); ylabel('Frequency (kHz)');

%% ========== SAMPLE RATE VARIATION ==========
fprintf('\nGenerating sample rate variations...\n');
fs_up   = fs_orig * 4;
fs_down = round(fs_orig / 2);

x_up   = resample(x_eq, 4, 1);
x_down = resample(x_eq, 1, 2);

fprintf('  Original    : Fs = %d Hz | %d samples\n', fs_orig, length(x_eq));
fprintf('  Upsampled   : Fs = %d Hz | %d samples\n', fs_up,   length(x_up));
fprintf('  Downsampled : Fs = %d Hz | %d samples\n', fs_down, length(x_down));

% PSD at all three sample rates
figure('Name', 'PSD — Sample Rate Comparison', 'NumberTitle', 'off');
pwelch(x_eq,   1024, 512, 1024, fs_orig); hold on;
pwelch(x_up,   1024, 512, 1024, fs_up);
pwelch(x_down, 1024, 512, 1024, fs_down);
legend(sprintf('Original (Fs=%d)', fs_orig), ...
       sprintf('4x Upsample (Fs=%d)', fs_up), ...
       sprintf('0.5x Downsample (Fs=%d)', fs_down), ...
       'Location', 'best');
title('PSD — Sample Rate Comparison'); grid on;
xlabel('Frequency (Hz)'); ylabel('Power/Frequency (dB/Hz)');

% Spectrogram of upsampled output
figure('Name', 'Spectrogram — Upsampled (4x)', 'NumberTitle', 'off');
spectrogram(x_up, 512, 256, 512, fs_up, 'yaxis');
title(sprintf('Spectrogram — Upsampled (Fs = %d Hz)', fs_up));

% Spectrogram of downsampled output
figure('Name', 'Spectrogram — Downsampled (0.5x)', 'NumberTitle', 'off');
spectrogram(x_down, 512, 256, 512, fs_down, 'yaxis');
title(sprintf('Spectrogram — Downsampled (Fs = %d Hz)', fs_down));

%% ========== FIR vs IIR COMPARISON ==========
% Always shown regardless of selected filter type
fprintf('\nFIR vs IIR Comparison — Band 800-2000 Hz\n');
f1d = 800  / nyq;
f2d = 2000 / nyq;

b_fir_cmp              = fir1(filter_order, [f1d f2d], 'bandpass', blackman(filter_order+1));
[b_but_cmp, a_but_cmp] = butter(4,  [f1d f2d]);
[b_chb_cmp, a_chb_cmp] = cheby1(4, 0.5, [f1d f2d]);

[Hf, ff] = freqz(b_fir_cmp, 1,          1024, fs_orig);
[Hb, ~]  = freqz(b_but_cmp, a_but_cmp,  1024, fs_orig);
[Hc, ~]  = freqz(b_chb_cmp, a_chb_cmp,  1024, fs_orig);

figure('Name', 'FIR vs IIR Comparison', 'NumberTitle', 'off');

subplot(2,1,1);
plot(ff, 20*log10(abs(Hf)+eps), 'b',   'LineWidth', 1.5); hold on;
plot(ff, 20*log10(abs(Hb)+eps), 'r--', 'LineWidth', 1.5);
plot(ff, 20*log10(abs(Hc)+eps), 'g:',  'LineWidth', 1.5);
legend('FIR (Blackman)', 'IIR Butterworth', 'IIR Chebyshev');
title('Magnitude Response — FIR vs IIR (800-2000 Hz)');
xlabel('Frequency (Hz)'); ylabel('Magnitude (dB)'); grid on;

subplot(2,1,2);
plot(ff, unwrap(angle(Hf))*180/pi, 'b',   'LineWidth', 1.5); hold on;
plot(ff, unwrap(angle(Hb))*180/pi, 'r--', 'LineWidth', 1.5);
plot(ff, unwrap(angle(Hc))*180/pi, 'g:',  'LineWidth', 1.5);
legend('FIR (Blackman)', 'IIR Butterworth', 'IIR Chebyshev');
title('Phase Response — FIR vs IIR (800-2000 Hz)');
xlabel('Frequency (Hz)'); ylabel('Phase (degrees)'); grid on;

sgtitle('FIR vs IIR — Magnitude and Phase Comparison', 'FontWeight', 'bold');

%% ========== SAVE OUTPUT FILES ==========
audiowrite('output_equalized.wav', max(min(x_eq,   0.99), -0.99), fs_orig);
audiowrite('output_x4.wav',        max(min(x_up,   0.99), -0.99), fs_up);
audiowrite('output_x05.wav',       max(min(x_down, 0.99), -0.99), fs_down);

fprintf('\nFiles saved:\n');
fprintf('  output_equalized.wav  (Fs = %d Hz)\n', fs_orig);
fprintf('  output_x4.wav         (Fs = %d Hz)\n', fs_up);
fprintf('  output_x05.wav        (Fs = %d Hz)\n', fs_down);

%% ========== PLAY OUTPUT ==========
fprintf('\nPlaying equalized signal...\n');
sound(x_eq, fs_orig);

fprintf('\n=== PART II COMPLETED SUCCESSFULLY ===\n');



