function [ecg, fs, t] = load_ecg(record_name, num_samples)
% LOAD_ECG Load MIT-BIH Record directly from .dat and .hea files

    if nargin < 1
        record_name = '100';
    end
    
    % Load header to get info
    hea_file = [record_name '.hea'];
    if ~exist(hea_file, 'file')
        error('File %s not found. Make sure 100.dat and 100.hea are in the folder.', hea_file);
    end
    
    % Read the signal using simple method for MIT-BIH format
    fid = fopen([record_name '.dat'], 'r');
    val = fread(fid, [2, inf], 'int16')';   % 2 leads, read all samples
    fclose(fid);
    
    % Take Lead I (first column) and convert to mV
    ecg = (val(:,1) - 1024) / 200;   % Standard scaling for MIT-BIH
    ecg = ecg(:);                     % Make sure it's a column vector
    
    fs = 360;                         % Sampling frequency
    
    if nargin > 1 && num_samples > 0
        ecg = ecg(1:min(num_samples, length(ecg)));
    end
    
    t = (0:length(ecg)-1)' / fs;
    
    fprintf('✅ Successfully loaded Record %s\n', record_name);
    fprintf('   Length: %d samples (%.2f seconds)\n', length(ecg), length(ecg)/fs);
    fprintf('   Sampling Rate: %d Hz\n', fs);
end