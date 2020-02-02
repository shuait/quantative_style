% streamline script to run following experiments for eccv18 style paper Pb
% eval
% Experiment steps
% 1. generate pb map given the weight, content, style sample
% 2. (optional) re-organize stylized images and Pb maps file structure
% 3. use evaluztion scripts to evaluate on Pb and generate eval file for
% every image
% 4. collect boundary evaluation results from all eval files
% 5. may repeat step 1-4 for multiple set of sample parameter combinations

%% configurations params

addpath ../bench/benchmarks
addpath ../bench
addpath ../grouping/lib


clear all;close all;clc;


PERM_GT = false;
isBoosting = false;
boosting_iter = 1;




%%%%%%%%%%%%%%%%%%%methods spec%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%% sample files%%%%%%%%%%%%%%%%%%%%%%
sample_file = './wcs1.txt';
this_trial = 'round1';


% %first batch 300 samples from gatys
% method = 'Gatys';
% imgFolder = 'Gatysampled15';

% %first batch 300 samples from crosslayer
% method = 'CrossLayer';
% imgFolder = 'AddCrossampled15';

%first batch 300 samples from universal style transfer
method = 'Universal';
imgFolder = 'Universal_style300';

% %first batch 300 samples from histogram loss
% method = 'HistLoss';
% imgFolder = 'Histogram';

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%% sample files%%%%%%%%%%%%%%%%%%%%%%
% 
% sample_file = './wcs2.txt';
% this_trial = 'round2';


%second batch 300 samples from gatys
% method = 'Gatys';
% imgFolder = 'More_GatysSample';

% %second batch 300 samples from crosslayer
% method = 'CrossLayer';
% imgFolder = 'More_OursSample';



% % calibration experiment, all 300 stylized images are original contents
% method = 'allContent';
% imgFolder = 'AllContSampled';

% % calibration experiment 2, all 300 stylized images are original styles
% method = 'allStyle';
% imgFolder = 'AllStyleSampled';



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
img_dir = '../BSDS500/data/images';
gtDir = '../BSDS500/data/groundTruth';
rstDir = '../BSDS500/ucm2/SampleTests';

SampleImgDir = fullfile(img_dir,imgFolder);
rstDir = fullfile(rstDir,method);

PbOutDir = fullfile(rstDir,'PbRsts');

if PERM_GT == 0
    gtDir = fullfile(gtDir,'test');
else
    gtDir = fullfile(gtDir,'test_selected_perm');
end
   
if PERM_GT ==0
    EvalOutDir = fullfile(rstDir,strcat(this_trial,'_eval'));
    Eval_stat_outDir = fullfile(rstDir,strcat(this_trial,'_eval_sum'));
else
    EvalOutDir = fullfile(rstDir,strcat(this_trial,'_perm_eval'));
    Eval_stat_outDir = fullfile(rstDir,strcat(this_trial,'_perm_eval_sum'));
end

mkdir(EvalOutDir);
mkdir(Eval_stat_outDir);


% open parpool
% delete(gcp);
% parpool('local_Copy',8); %6/8 workers

%% get Pb maps

% note all stylized images will be stored in one folder, so as the Pb maps
% it is untill when evaluated, samples from different trial will be stored
% in indivisual folders.

%read from wcs file
samples = dlmread(sample_file);
image_names = getImgnamesBySample(samples); % return an cell array of image filenames, copy images to directory
mkdir(PbOutDir);
all_file_dir(1:length(image_names)) = struct('name',[],'date',[],'bytes',[],'isdir',[],'datenum',[]);

for i =1:numel(image_names)
    
    PbOutFile = fullfile(PbOutDir,[image_names{i}(1:end-4) '.mat']); 
    imgFile=fullfile(SampleImgDir,image_names{i});
    
    if ~exist(imgFile,'file')
        imgFile = strrep(imgFile,'.png','.jpg');
    end
    
    disp(imgFile)
    all_file_dir(i) = dir(imgFile);
    if exist(PbOutFile,'file'), continue; end
    im2ucm(imgFile, PbOutFile);
end

%% evaluation 

tic;
boundaryBench_sty_trials(all_file_dir, gtDir, PbOutDir, EvalOutDir,isBoosting)
toc;



%% collect eval rsts and generate AUC
% note this needs to be executed for every weights

iter =1;
if isBoosting, iter = boosting_iter;end 
sum_AUC = zeros(iter,1); 
   
for k=1:iter
   fprintf('iter: %d\n',k)
    % randomly sample image to evaluate, sort of like boosting
    if isBoosting,
        iids = cell(length(image_names),1);

        for j = 1:numel(all_file_dir),      
            iids{j} = all_file_dir(randi(length(all_file_dir))).name;
        end
    else
        iids = all_file_dir;
    end
    
    %  get per image AUCs
    eval_file_dirs = fullfile(EvalOutDir,strrep(strrep({iids.name},'.png','_ev1.txt'),'.jpg','_ev1.txt'));
    AUCs = zeros(length(eval_file_dirs),1);
    
    this_weight_eval_stat_ourDir = fullfile(Eval_stat_outDir,'all');
    mkdir(this_weight_eval_stat_ourDir);
        
    for j = 1:length(eval_file_dirs)

       [bestF, bestP, bestR, bestT, F_max, P_max, R_max, Area_PR] = collect_eval_bdry_sty(this_weight_eval_stat_ourDir,eval_file_dirs(j));
        AUCs(j) = Area_PR;
        
    end
      rsts = [samples AUCs];
     save(fullfile(this_weight_eval_stat_ourDir,[method '_everyImgAUC.mat']),'rsts');
    
end 


