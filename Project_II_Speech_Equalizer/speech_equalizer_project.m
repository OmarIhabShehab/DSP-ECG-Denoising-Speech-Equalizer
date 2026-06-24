%% =========================================================================
%  Multi-Band Speech Equalizer for Podcast Enhancement
%  DSP Course Project — Final Fixed & Stabilized Version
%% =========================================================================
clear; clc;
set(0, 'DefaultFigureWindowStyle', 'normal');

%% ================= USER INPUTS =================
fprintf('====================================================\n');
fprintf(' MULTI-BAND SPEECH EQUALIZER\n');
fprintf('====================================================\n');

% ---------- Audio File ----------
audio_file = input('Enter audio file name (example: Test1_man.wav): ','s');

% ---------- Filter Type ----------
fprintf('\nFilter Types:\n');
fprintf('1 -> FIR\n');
fprintf('2 -> IIR\n');
filter_choice = input('Choose filter type (1 or 2): ');

if filter_choice == 1
    filter_type = 'FIR';
    fprintf('\nFIR Window Types:\n');
    fprintf('1 -> Hamming\n');
    fprintf('2 -> Hanning\n');
    fprintf('3 -> Blackman\n');
    win_choice = input('Choose FIR window type: ');
    switch win_choice
        case 1, fir_window = 'Hamming';
        case 2, fir_window = 'Hanning';
        case 3, fir_window = 'Blackman';
        otherwise, error('Invalid FIR window choice.');
    end
else
    filter_type = 'IIR';
    fprintf('\nIIR Types:\n');
    fprintf('1 -> Butterworth\n');
    fprintf('2 -> Chebyshev Type I\n');
    fprintf('3 -> Chebyshev Type II\n');
    iir_choice = input('Choose IIR type: ');
    switch iir_choice
        case 1, iir_subtype = 'Butterworth';
        case 2, iir_subtype = 'Chebyshev1';
        case 3, iir_subtype = 'Chebyshev2';
        otherwise, error('Invalid IIR type.');
    end
end

% ---------- Filter Order ----------
filter_order = input('\nEnter filter order: ');

% ضبط رتبة الفلتر
if strcmp(filter_type, 'FIR')
    if mod(filter_order, 2) ~= 0
        filter_order = filter_order + 1;
        fprintf('Note: FIR order adjusted to %d (must be even).\n', filter_order);
    end
    filter_order = max(filter_order, 4); % حد أدنى للـ FIR
else
    filter_order = min(filter_order, 8); % حد أقصى للـ IIR تفادياً للعدم استقرار
    filter_order = max(filter_order, 2);
    fprintf('Note: IIR order clamped to %d for stability.\n', filter_order);
end

% ---------- Output Sample Rate ----------
fprintf('\nOutput Sample Rate Options:\n');
fprintf('1 -> Original Fs\n');
fprintf('2 -> 4x Fs\n');
fprintf('3 -> 0.5x Fs\n');
fs_choice = input('Choose output sample rate option: ');

% ---------- Mode ----------
fprintf('\nModes:\n');
fprintf('1 -> Preset Mode\n');
fprintf('2 -> Custom Mode\n');
mode_choice = input('Choose mode: ');
if mode_choice == 1
    mode = 'preset';
else
    mode = 'custom';
end

%% ================= LOAD AUDIO =================
if ~exist(audio_file, 'file')
    fprintf('\nAudio file not found. Generating synthetic signal...\n');
    fs_orig = 44100;
    t_syn   = (0:fs_orig*3-1)' / fs_orig;
    x = 0.3*sin(2*pi*200*t_syn)  + ...
        0.5*sin(2*pi*800*t_syn)  + ...
        0.4*sin(2*pi*2000*t_syn) + ...
        0.2*sin(2*pi*5000*t_syn) + ...
        0.1*randn(size(t_syn));
    x = x / max(abs(x));
    audiowrite(audio_file, x, fs_orig);
    fprintf('Synthetic signal saved as "%s"\n', audio_file);
end

[x_orig, fs_orig] = audioread(audio_file);
if size(x_orig,2) > 1
    x_orig = mean(x_orig, 2);   % تحويل stereo -> mono
end
x_orig = x_orig / max(abs(x_orig));   % تطبيع
nyq    = fs_orig / 2;

fprintf('\nFile Loaded Successfully\n');
fprintf('Fs     = %d Hz\n',   fs_orig);
fprintf('Length = %.2f sec\n', length(x_orig)/fs_orig);

%% ================= BAND DEFINITIONS =================
if strcmp(mode,'preset')
    band_edges  = [0 100 300 800 2000 5000 10000 20000];
    band_labels = {'0-100','100-300','300-800','800-2k', ...
                   '2k-5k','5k-10k','10k-20k'};
    fprintf('\nPreset Speech Bands Selected.\n');
    fprintf('\nEnter Gain for Each Band (dB)\n');
    gains_dB = zeros(1,7);
    for k = 1:7
        fprintf('Band %s Hz: ', band_labels{k});
        gains_dB(k) = input('');
    end
else
    fprintf('\n========== CUSTOM MODE ==========\n');
    num_bands = input('Enter number of bands (5 to 10): ');
    if num_bands < 5 || num_bands > 10
        error('Number of bands must be between 5 and 10.');
    end
    fprintf('Enter band edges (first=0, last=20000):\n');
    band_edges = input('Enter edges as vector: ');
    if band_edges(1) ~= 0 || band_edges(end) ~= 20000
        error('Band edges must start at 0 and end at 20000.');
    end
    if length(band_edges) ~= num_bands + 1
        error('Number of edges must equal num_bands + 1.');
    end
    gains_dB  = zeros(1, num_bands);
    band_labels = cell(1, num_bands);
    for k = 1:num_bands
        band_labels{k} = sprintf('%d-%d', band_edges(k), band_edges(k+1));
        fprintf('Gain for Band %d (%s Hz): ', k, band_labels{k});
        gains_dB(k) = input('');
    end
end
num_bands = length(band_edges) - 1;

%% ================= FILTER DESIGN =================
% تخزين [b,a] للتحليل و SOS للتطبيق
filters_b   = cell(num_bands, 1);
filters_a   = cell(num_bands, 1);
filters_sos = cell(num_bands, 1);   % <-- FIX #1: SOS الصحيح

Rp = 0.5;   % Chebyshev I ripple (dB)
Rs = 40;    % Chebyshev II stopband (dB)

fprintf('\nDesigning Filters...\n');
for k = 1:num_bands

    % ---- حماية حدود التردد ----
    f1 = band_edges(k)   / nyq;
    f2 = band_edges(k+1) / nyq;
    f1 = min(max(f1, 0.001), 0.998);
    f2 = min(max(f2, 0.002), 0.999);
    if f1 >= f2
        f1 = max(f2 - 0.001, 0.0001);
    end

    %% ---------- FIR ----------
    if strcmp(filter_type, 'FIR')
        switch fir_window
            case 'Hamming',  win = hamming(filter_order+1);
            case 'Hanning',  win = hann(filter_order+1);
            case 'Blackman', win = blackman(filter_order+1);
        end
        if k == 1
            b = fir1(filter_order, f2,        'low',      win);
        elseif k == num_bands
            b = fir1(filter_order, f1,        'high',     win);
        else
            b = fir1(filter_order, [f1 f2],   'bandpass', win);
        end
        a = 1;
        % FIX #2: تحويل FIR كمان لـ SOS لتوحيد طريقة التطبيق
        filters_sos{k} = tf2sos(b, a);

    %% ---------- IIR ----------
    else
        % الحل الصح: نستخدم [z,p,k] مباشرة ثم zp2sos
        % zp2sos اكثر استقرارا رقميا من tf2sos لانه يتجنب تماما الـ [b,a] المتوسطة
        if strcmp(iir_subtype, 'Butterworth')
            if k == 1
                [z,p,kg] = butter(filter_order, f2, 'low');
            elseif k == num_bands
                [z,p,kg] = butter(filter_order, f1, 'high');
            else
                [z,p,kg] = butter(filter_order, [f1 f2], 'bandpass');
            end
        elseif strcmp(iir_subtype, 'Chebyshev1')
            if k == 1
                [z,p,kg] = cheby1(filter_order, Rp, f2, 'low');
            elseif k == num_bands
                [z,p,kg] = cheby1(filter_order, Rp, f1, 'high');
            else
                [z,p,kg] = cheby1(filter_order, Rp, [f1 f2], 'bandpass');
            end
        elseif strcmp(iir_subtype, 'Chebyshev2')
            if k == 1
                [z,p,kg] = cheby2(filter_order, Rs, f2, 'low');
            elseif k == num_bands
                [z,p,kg] = cheby2(filter_order, Rs, f1, 'high');
            else
                [z,p,kg] = cheby2(filter_order, Rs, [f1 f2], 'bandpass');
            end
        end
        % zp2sos: يدمج الـ gain ويرتب الـ sections لاقصى استقرار
        filters_sos{k} = zp2sos(z, p, kg);
        % [b,a] للتحليل فقط (freqz, zplane)
        [b, a] = zp2tf(z, p, kg);
        filters_b{k} = b;
        filters_a{k} = a;
    end

    if strcmp(filter_type, 'FIR')
        filters_b{k} = b;
        filters_a{k} = a;
    end

    fprintf('Band %d [%s Hz] Designed\n', k, band_labels{k});
end

%% ================= FILTER ANALYSIS =================
fprintf('\nGenerating Filter Analysis Plots...\n');
for k = 1:num_bands
    figure('Name', sprintf('Band %d Analysis', k), 'NumberTitle', 'off');

    % FIX #3: freqz من [b,a] بشكل موحد (آمن للـ FIR والـ IIR)
    [H, f] = freqz(filters_b{k}, filters_a{k}, 1024, fs_orig);

    subplot(3,2,1);
    plot(f, 20*log10(abs(H)+eps), 'LineWidth', 1.2);
    grid on; title('Magnitude Response');
    xlabel('Frequency (Hz)'); ylabel('Magnitude (dB)');

    subplot(3,2,2);
    plot(f, unwrap(angle(H))*180/pi, 'LineWidth', 1.2);
    grid on; title('Phase Response');
    xlabel('Frequency (Hz)'); ylabel('Phase (deg)');

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

    sgtitle(sprintf('Band %d : %s Hz', k, band_labels{k}), 'FontWeight', 'bold');
end

%% ================= APPLY FILTERS =================
fprintf('\nApplying Filters...\n');
x_bands  = zeros(length(x_orig), num_bands);
x_gained = zeros(length(x_orig), num_bands);

for k = 1:num_bands
    % FIR: filtfilt([b,a]) آمن ومستقر دايماً
    % IIR: sosfilt على SOS المبني بـ zp2sos (الاكثر استقرارا)
    if strcmp(filter_type, 'FIR')
        tmp = filtfilt(filters_b{k}, filters_a{k}, x_orig);
    else
        tmp = sosfilt(filters_sos{k}, x_orig);
    end

    % حماية من NaN: لو في NaN يبقى في مشكلة في التصميم نصفر الباند
    if any(isnan(tmp)) || any(isinf(tmp))
        fprintf('WARNING: Band %d produced NaN/Inf — zeroed out.\n', k);
        tmp = zeros(size(x_orig));
    end

    x_bands(:,k)  = tmp;
    gain = 10^(gains_dB(k)/20);
    x_gained(:,k) = gain * x_bands(:,k);
    fprintf('Band %d [%s Hz] — Gain = %+.1f dB\n', k, band_labels{k}, gains_dB(k));
end

x_eq = sum(x_gained, 2);

% تطبيع آمن: بس لو الإشارة اتشبعت (clipping) — مش دايماً
% ده بيحافظ على أثر الـ gain الحقيقي ومش بيلغيه
peak = max(abs(x_eq));
if peak < eps
    error('Output signal is all zeros. Check filter design or gains.');
end
if peak > 1.0
    % طبّع بس لو في clipping فعلي
    x_eq = x_eq / peak;
    fprintf('Note: Output normalized to prevent clipping.\n');
end

%% ================= PERFORMANCE METRICS =================
rms_orig = sqrt(mean(x_orig.^2));
rms_eq   = sqrt(mean(x_eq.^2));
p_change = 10*log10(mean(x_eq.^2) / mean(x_orig.^2));
rho      = corrcoef(x_orig, x_eq);

fprintf('\n========== PERFORMANCE ==========\n');
fprintf('Original RMS  = %.4f\n', rms_orig);
fprintf('Equalized RMS = %.4f\n', rms_eq);
fprintf('Power Change  = %.2f dB\n', p_change);
fprintf('Correlation   = %.4f\n', rho(1,2));

%% ================= TIME DOMAIN PLOT =================
t_axis  = (0:length(x_orig)-1)' / fs_orig;
seg_end = min(round(0.05*fs_orig), length(x_orig));

figure('Name', 'Time Domain Comparison');
subplot(2,1,1);
plot(t_axis(1:seg_end), x_orig(1:seg_end), 'LineWidth', 1.2);
title('Original Signal'); xlabel('Time (s)'); ylabel('Amplitude'); grid on;

subplot(2,1,2);
plot(t_axis(1:seg_end), x_eq(1:seg_end), 'LineWidth', 1.2, 'Colosr', [0.85 0.33 0.1]);
title('Equalized Signal'); xlabel('Time (s)'); ylabel('Amplitude'); grid on;

%% ================= PSD COMPARISON =================
% FIX #4: pwelch صح — بنحسب المتجهات أولاً وبعدين نرسم مع بعض
figure('Name', 'PSD Comparison');
[P1, F1] = pwelch(x_orig, 1024, 512, 1024, fs_orig);
[P2, F2] = pwelch(x_eq,   1024, 512, 1024, fs_orig);
plot(F1, 10*log10(P1), 'b', 'LineWidth', 1.2); hold on;
plot(F2, 10*log10(P2), 'r', 'LineWidth', 1.2);
legend('Original','Equalized'); grid on;
title('Power Spectral Density');
xlabel('Frequency (Hz)'); ylabel('PSD (dB/Hz)');

%% ================= SPECTROGRAM + DIFFERENCE =================
figure('Name', 'Spectrogram Analysis & Difference', 'NumberTitle', 'off');

subplot(3,1,1);
spectrogram(x_orig, 512, 256, 512, fs_orig, 'yaxis');
title('1. Original Spectrogram');

subplot(3,1,2);
spectrogram(x_eq, 512, 256, 512, fs_orig, 'yaxis');
title('2. Equalized Spectrogram');

subplot(3,1,3);
[S_orig, F_sp, T_sp] = spectrogram(x_orig, 512, 256, 512, fs_orig);
[S_eq,  ~,    ~]     = spectrogram(x_eq,   512, 256, 512, fs_orig);
Mag_diff = 20*log10(abs(S_eq)+eps) - 20*log10(abs(S_orig)+eps);
imagesc(T_sp, F_sp/1000, Mag_diff);
axis xy; colorbar; colormap(gca, jet);
clim([-20 20]);   % نثبت الـ color scale عشان يبان الفرق بوضوح
title('3. Spectrogram Difference (Equalized - Original) in dB');
xlabel('Time (s)'); ylabel('Frequency (kHz)');

%% ================= OUTPUT SAMPLE RATE =================
fs_out = fs_orig;
x_out  = x_eq;
switch fs_choice
    case 2
        fs_out = fs_orig * 4;
        x_out  = resample(x_eq, 4, 1);
        fprintf('\nUpsampled to %d Hz\n', fs_out);
    case 3
        fs_out = round(fs_orig / 2);
        x_out  = resample(x_eq, 1, 2);
        fprintf('\nDownsampled to %d Hz\n', fs_out);
    otherwise
        fprintf('\nOutput Sample Rate = %d Hz (Original)\n', fs_out);
end

%% ================= SAVE OUTPUT =================
output_name = 'output_equalized.wav';
audiowrite(output_name, max(min(x_out, 0.99), -0.99), fs_out);
fprintf('Output Saved: %s\n', output_name);

%% ================= PLAY OUTPUT =================
fprintf('\nPlaying equalized audio...\n');
sound(x_out, fs_out);
fprintf('\n=== PROJECT COMPLETED SUCCESSFULLY ===\n');