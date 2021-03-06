% Copyright   : Michael Pokojovy & Valerii Maltsev (2020)
% Version     : 2.0
% Last edited : 11/27/2020
% License     : Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
%               https://creativecommons.org/licenses/by-sa/4.0/

%% Set random seed for reproducibility
rng(1);

%% Loading and plotting 2018 data
yield2018 = readmatrix("yield2018.csv");
yield2018 = yield2018(:, 2:(end - 1));

[n, p] = size(yield2018);

[~, ind_nan] = min(isnan(yield2018(:, 2)));
ind_nan = ind_nan - 1;

month = [1 2 3 6];
month = [month 12*[1 2 3 5 7 10 20 30]];

I = 1:length(month);
I = setdiff(I, 2);
for i = 1:ind_nan
    yield2018(i, 2) = interp1(month(I), yield2018(i, I), month(2));
end

time_grid    = (1:n)*(12/n);
horizon_grid = month;

figure(1);
set(gcf, 'PaperUnits', 'centimeters');
xSize = 28; ySize = 16;
xLeft = (21 - xSize)/2; yTop = (30 - ySize)/2;
set(gcf, 'PaperPosition', [xLeft yTop xSize ySize]);
set(gcf, 'Position', [0 0 xSize*50 ySize*50]);

[Time, Horizon] = meshgrid(time_grid(:), horizon_grid);

surf(Time, Horizon, yield2018');
xlabel({'Calendar time $t$', '(in months)'}, 'FontSize', 25, 'interpreter', 'latex');
ylabel({'Time to maturity $x$', '(in months)'}, 'FontSize', 25, 'interpreter', 'latex');
zlabel({'Yield rate $y_{t}(x)$', '(in \%)'}, 'FontSize', 25, 'interpreter', 'latex');

n_month = 7;
month = month(1:n_month); % Truncate the maturities at 3 yr

%% Loading 2019 data
yield2019 = readmatrix("yield2019.csv");
yield2019 = yield2019(:, 2:(end - 1));

%% Preparing the forward curves
T_grid     = linspace(0, 12, n); % 1-year span
X_grid     = linspace(1, month(end), month(end)/12*n); % 3-year span

dx = X_grid(2) - X_grid(1);
dt = T_grid(2) - T_grid(1);

X_grid_ext = [(0:dx:(1 - dx)) X_grid]; % extended 3-year span

yield_obs = zeros(length(T_grid), length(X_grid_ext));
Y_obs     = zeros(size(yield_obs));

for i = 1:length(T_grid)
    yield_obs(i, :) = interp1([0 month], [yield2018(i, 1) yield2018(i, 1:n_month)], X_grid_ext, 'spline');
    Y_obs(i, :)     = X_grid_ext.*yield_obs(i, :);
end

I_T = ceil(linspace(1, length(T_grid), 150));
I_X = ceil(linspace(1, length(X_grid_ext), 20));

figure(2);
set(gcf, 'PaperUnits', 'centimeters');
xSize = 28; ySize = 16;
xLeft = (21 - xSize)/2; yTop = (30 - ySize)/2;
set(gcf, 'PaperPosition', [xLeft yTop xSize ySize]);
set(gcf, 'Position', [0 0 xSize*50 ySize*50]);

[Time, Horizon] = meshgrid(T_grid(I_T), X_grid_ext(I_X));
surf(Time, Horizon, Y_obs(I_T, I_X)');

xlabel({'Calendar time $t$', '(in months)'}, 'FontSize', 25, 'interpreter', 'latex');
ylabel({'Time to maturity $x$', '(in months)'}, 'FontSize', 25, 'interpreter', 'latex');
zlabel({'Integrated forward rate $Y(t, x)$', '(in $\% \times \textrm{month}$)'}, 'FontSize', 25, 'interpreter', 'latex');

%% Estimation of Vasicek's model
r_obs = yield_obs(:, 1);
[alpha_hat, r_ast_hat, beta_hat] = Vasicek_inv_map(T_grid, yield_obs(:, 1));
display(['Vasicek''s model: alpha-hat = ', num2str(alpha_hat), ...
         ', r*-hat = ', num2str(r_ast_hat), ', beta-hat = ', num2str(beta_hat)]);

%% Inverse problem for the abstract Heath-Jarrow-Morton model
[I_sigma_HJM_hat, lambda_HJM_hat] = HJM_inv_map(T_grid, X_grid_ext, Y_obs, r_obs, 0.99);

display(['HJM model: lambda-hat = ', num2str(lambda_HJM_hat')]);

n_mode = size(I_sigma_HJM_hat, 1);

figure(3);
set(gcf, 'PaperUnits', 'centimeters');
xSize = 28; ySize = 16;
xLeft = (21 - xSize)/2; yTop = (30 - ySize)/2;
set(gcf, 'PaperPosition', [xLeft yTop xSize ySize]);
set(gcf, 'Position', [0 0 xSize*50 ySize*50]);

hold on;

xlabel('$x$', 'FontSize', 25, 'interpreter', 'latex');
ylabel('Principal curves $\mathcal{I}_{x} \sigma_{n}$', 'FontSize', 25, 'interpreter', 'latex');

axis([min(X_grid_ext) max(X_grid_ext) 1.05*min(I_sigma_HJM_hat, [], 'all') 1.05*max(I_sigma_HJM_hat, [], 'all')]);

for i = 1:n_mode
    plot(X_grid_ext, I_sigma_HJM_hat(i, :), 'LineWidth', 2, 'MarkerSize', 0.01);
end

legend({'$\mathcal{I}_{x} \sigma_{1}$', '$\mathcal{I}_{x} \sigma_{2}$', '$\mathcal{I}_{x} \sigma_{3}$', ...
        '$\mathcal{I}_{x} \sigma_{4}$', '$\mathcal{I}_{x} \sigma_{5}$', '$\mathcal{I}_{x} \sigma_{6}$'}, ...
        'FontSize', 25, 'interpreter', 'latex', 'Location', 'NorthWest');

%% Prediction for Y
n_rep = 10000;
conf  = 0.99;

T_pred = 22; % February 1, 2019 - corresponds to 22/250*12 = 1.0560 month in 2019
date   = 'February 1, 2019';

T_grid_pred = T_grid(1:ceil(T_pred*length(T_grid)/size(yield2018, 1)));
t_pred = T_grid_pred(end);

% Predicting the short rates f_{t}(0) with Vasicek's model
pred0 = Vasicek_fwd_map(T_grid_pred, yield_obs(end, 1), alpha_hat, r_ast_hat, beta_hat, n_rep);
% Predicting integrated forward rates with HJM model
pred  = HJM_fwd_map(T_grid_pred, X_grid_ext, Y_obs(end, :), pred0, I_sigma_HJM_hat, lambda_HJM_hat, n_rep);

yield_pred = zeros(length(X_grid_ext), n_rep);

for j = 1:n_rep
    yield_pred(:, j) = pred(end, :, j)./X_grid_ext;
    yield_pred(1, j) = yield_pred(2, j);
end

yield_lq  = zeros(size(X_grid_ext));
yield_hq  = zeros(size(X_grid_ext));
yield_avg = zeros(size(X_grid_ext));

for i = 1:length(X_grid_ext)
    yield_lq(i)  = quantile(yield_pred(i, :), (1 - conf)/2);
    yield_hq(i)  = quantile(yield_pred(i, :), 1 - (1 - conf)/2);
    yield_avg(i) = mean(yield_pred(i, :));
end

I_X = find(ismember(X_grid_ext, X_grid));

% One-month prediction
figure(4);
set(gcf, 'PaperUnits', 'centimeters');
xSize = 28; ySize = 16;
xLeft = (21 - xSize)/2; yTop = (30 - ySize)/2;
set(gcf, 'PaperPosition', [xLeft yTop xSize ySize]);
set(gcf, 'Position', [0 0 xSize*50 ySize*50]);

hold on;

xlabel({'Time to maturity $x$', '(in months)'}, 'FontSize', 25, 'interpreter', 'latex');
ylabel({['Predicted yields $y_{t}(x)$ on $t = \textrm{', date, '}$'], '(in \%)'}, 'FontSize', 25, 'interpreter', 'latex');

axis([min(X_grid_ext(I_X)) max(X_grid_ext(I_X)) 0 4]);

plot(X_grid, interp1(month, yield2019(T_pred, 1:n_month), X_grid), 'k', 'LineWidth', 3);
plot(X_grid_ext(I_X), yield_lq(I_X),  'k:',  'LineWidth', 2);
plot(X_grid_ext(I_X), yield_hq(I_X),  'k:',  'LineWidth', 2);
plot(X_grid_ext(I_X), yield_avg(I_X), 'k-.', 'LineWidth', 2);

for i = 1:5
    plot(X_grid_ext(I_X), yield_pred(I_X, i));
end

legend({'Observed yield curve', 
       ['Lower $', num2str(100*conf), '\%$ pointwise prediction bound'],
       ['Upper $', num2str(100*conf), '\%$ pointwise prediction bound'],
       ['Estimated mean yield curve'],
       ['Five sample yield curve forecasts']}, ...
        'FontSize', 25, 'interpreter', 'latex', 'Location', 'SouthWest');
    
% One-month avg. rate curve estimation
figure(5);
set(gcf, 'PaperUnits', 'centimeters');
xSize = 36; ySize = 16;
xLeft = (21 - xSize)/2; yTop = (30 - ySize)/2;
set(gcf, 'PaperPosition', [xLeft yTop xSize ySize]);
set(gcf, 'Position', [0 0 xSize*50 ySize*50]);

% Observed
subplot(1, 2, 1);
hold on;

xlabel({'Calendar time $t$', '(in months)'}, 'FontSize', 25, 'interpreter', 'latex');
ylabel({'Time to maturity $x$', '(in months)'}, 'FontSize', 25, 'interpreter', 'latex');
zlabel({'Obs. yield rate $y_{t}(x)$', '(in \%)'}, 'FontSize', 25, 'interpreter', 'latex');

[Time, Horizon] = meshgrid(T_grid_pred, month);

surf(Time, Horizon, yield2019(1:T_pred, 1:n_month)');
axis([min(T_grid_pred) max(T_grid_pred), min(month) max(month), 0.0 2.9]);
view(-20, 50);

% Estimated mean
subplot(1, 2, 2);
hold on;

xlabel({'Calendar time $t$', '(in months)'}, 'FontSize', 25, 'interpreter', 'latex');
ylabel({'Time to maturity $x$', '(in months)'}, 'FontSize', 25, 'interpreter', 'latex');
zlabel({'Est. mean yield rate $\widehat{\mathrm{E}\big[y_{t}(x)\big]}$', '(in \%)'}, 'FontSize', 25, 'interpreter', 'latex');

mean_yield_pred = mean(pred, 3);

for i = 1:size(pred, 1)
    mean_yield_pred(i, :) = mean_yield_pred(i, :)./X_grid_ext;
end

I_T = 1:length(T_grid_pred);
I_X = ceil(linspace(1, length(X_grid_ext), 20));

[Time, Horizon] = meshgrid(T_grid_pred(I_T), X_grid_ext(I_X));

surf(Time, Horizon, mean_yield_pred(I_T, I_X)');
axis([min(T_grid_pred(I_T)) max(T_grid_pred(I_T)), min(X_grid_ext(I_X)) max(X_grid_ext(I_X)), 0.0 2.9]);
view(-20, 50);
