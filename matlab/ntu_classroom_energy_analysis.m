%% 南通大学教室节能监控方案 MATLAB 分析程序
% 功能：
% 1. 估算教室年度用电量和非监管浪费
% 2. 完成低、中、高三种情景分析
% 3. 模拟典型教室一天内的节能控制过程
% 4. 计算节电收益、碳减排量和静态回收期
%
% 运行后将在当前目录生成 CSV 数据表和 PNG 图片。

clear;
clc;
close all;

%% 1 基础参数
classroomCount = 397;              % 教室数量
electricityPrice = 0.85;           % 综合电价，元/kWh
carbonFactor = 0.5306;             % 电力排放因子，kgCO2/kWh
projectInvestment = 366e4;         % 项目投资，元

equipment = ["照明"; "风扇"; "空调"; "多媒体"];
powerKW = [1.30; 0.45; 8.00; 0.35];       % 单间教室平均功率，kW
annualHours = [2100; 450; 800; 900];      % 年运行时间，h
wasteRatio = [0.12; 0.15; 0.14; 0.08];   % 非监管浪费比例

%% 2 年度用电量及浪费估算
annualEnergyKWh = classroomCount .* powerKW .* annualHours;
wasteEnergyKWh = annualEnergyKWh .* wasteRatio;
wasteCostYuan = wasteEnergyKWh .* electricityPrice;

totalEnergyKWh = sum(annualEnergyKWh);
totalWasteKWh = sum(wasteEnergyKWh);
totalWasteCost = sum(wasteCostYuan);
overallWasteRatio = totalWasteKWh / totalEnergyKWh;
totalWasteCarbonKg = totalWasteKWh * carbonFactor;

energyTable = table( ...
    equipment, powerKW, annualHours, wasteRatio, ...
    annualEnergyKWh, wasteEnergyKWh, wasteCostYuan, ...
    'VariableNames', { ...
    '设备', '平均功率_kW', '年运行时间_h', '非监管比例', ...
    '年用电量_kWh', '浪费电量_kWh', '浪费电费_元'});

disp('表 1  教室年度用电量及非监管浪费估算');
disp(energyTable);
fprintf('全校教室年用电量：%.2f 万kWh\n', totalEnergyKWh / 1e4);
fprintf('非监管浪费电量：%.2f 万kWh\n', totalWasteKWh / 1e4);
fprintf('非监管浪费比例：%.2f%%\n', overallWasteRatio * 100);
fprintf('非监管浪费电费：%.2f 万元\n', totalWasteCost / 1e4);
fprintf('对应碳排放量：%.2f 吨CO2\n\n', totalWasteCarbonKg / 1000);

writetable(energyTable, '年度用电与浪费估算.csv', 'Encoding', 'UTF-8');

%% 3 年度用电构成图
figure('Color', 'w', 'Name', '年度用电构成');
barData = [annualEnergyKWh - wasteEnergyKWh, wasteEnergyKWh] / 1e4;
b = bar(categorical(equipment), barData, 'stacked');
b(1).FaceColor = [0.22, 0.49, 0.67];
b(2).FaceColor = [0.90, 0.45, 0.05];
xlabel('用电设备');
ylabel('年用电量 万kWh');
title('教室年度用电构成与非监管浪费');
legend('正常用电', '非监管浪费', 'Location', 'northwest');
grid on;
exportgraphics(gcf, '年度用电构成.png', 'Resolution', 300);

%% 4 低中高三种情景分析
scenario = ["低情景"; "中位情景"; "高情景"];
scenarioEnergyWanKWh = [265; totalEnergyKWh / 1e4; 530];
scenarioWasteWanKWh = [27; totalWasteKWh / 1e4; 86];
scenarioWasteRate = scenarioWasteWanKWh ./ scenarioEnergyWanKWh;
scenarioCostWanYuan = scenarioWasteWanKWh .* electricityPrice;

scenarioTable = table( ...
    scenario, scenarioEnergyWanKWh, scenarioWasteWanKWh, ...
    scenarioWasteRate, scenarioCostWanYuan, ...
    'VariableNames', { ...
    '情景', '年用电量_万kWh', '浪费电量_万kWh', ...
    '浪费率', '浪费电费_万元'});

disp('表 2  低中高情景分析');
disp(scenarioTable);
writetable(scenarioTable, '低中高情景分析.csv', 'Encoding', 'UTF-8');

figure('Color', 'w', 'Name', '情景分析');
yyaxis left;
bar(categorical(scenario), scenarioWasteWanKWh, 0.55, ...
    'FaceColor', [0.20, 0.55, 0.72]);
ylabel('浪费电量 万kWh');
yyaxis right;
plot(categorical(scenario), scenarioWasteRate * 100, '-o', ...
    'LineWidth', 2, 'MarkerSize', 7, 'Color', [0.85, 0.33, 0.10]);
ylabel('浪费率 %');
title('不同情景下的非监管用电浪费');
grid on;
exportgraphics(gcf, '情景分析.png', 'Resolution', 300);

%% 5 关键参数敏感性分析
% 分析空调年运行时间和空调浪费比例变化对总浪费量的影响。
acHoursRange = 600:50:1000;
acWasteRatioRange = 0.08:0.01:0.20;
[acHoursGrid, acWasteGrid] = meshgrid(acHoursRange, acWasteRatioRange);

otherWasteKWh = sum(wasteEnergyKWh([1, 2, 4]));
acWasteKWhGrid = classroomCount .* powerKW(3) .* ...
    acHoursGrid .* acWasteGrid;
totalWasteGrid = (otherWasteKWh + acWasteKWhGrid) / 1e4;

figure('Color', 'w', 'Name', '敏感性分析');
surf(acHoursGrid, acWasteGrid * 100, totalWasteGrid);
xlabel('空调年运行时间 h');
ylabel('空调非监管浪费比例 %');
zlabel('全校浪费电量 万kWh');
title('总浪费电量对空调参数的敏感性');
colorbar;
grid on;
view(135, 30);
exportgraphics(gcf, '空调参数敏感性分析.png', 'Resolution', 300);

%% 6 单间教室典型日控制仿真
% 仿真步长为 5 分钟，共 24 小时。
stepMinutes = 5;
timeHour = (0:stepMinutes:(24 * 60 - stepMinutes))' / 60;
n = numel(timeHour);

% 课表：8:00-11:40、14:00-17:30、19:00-21:00。
scheduled = false(n, 1);
scheduled = scheduled | (timeHour >= 8.00 & timeHour < 11.67);
scheduled = scheduled | (timeHour >= 14.00 & timeHour < 17.50);
scheduled = scheduled | (timeHour >= 19.00 & timeHour < 21.00);

% 模拟实际占用。部分课间无人，晚自习提前结束。
occupied = scheduled;
occupied(timeHour >= 9.67 & timeHour < 9.92) = false;
occupied(timeHour >= 15.67 & timeHour < 15.92) = false;
occupied(timeHour >= 20.50) = false;

% 模拟室外温度和自然照度。
outdoorTemperature = 25 + 7 * sin((timeHour - 8) / 24 * 2 * pi);
daylightLux = max(0, 650 * sin((timeHour - 6) / 12 * pi));

% 传统管理：课表开始时设备开启，直到课程时段结束。
traditionalLighting = scheduled;
traditionalFan = scheduled & outdoorTemperature >= 26;
traditionalAC = scheduled & outdoorTemperature >= 28;
traditionalMedia = scheduled;

% 节能控制：有人且环境条件满足时才开启。
% 无人延时关闭设为 10 分钟，即连续 2 个采样周期无人后关闭。
delaySteps = round(10 / stepMinutes);
occupiedDelayed = movmax(double(occupied), [delaySteps - 1, 0]) > 0;

smartLighting = occupiedDelayed & daylightLux < 350;
smartFan = occupiedDelayed & outdoorTemperature >= 26;
smartAC = occupiedDelayed & outdoorTemperature >= 28;
smartMedia = occupiedDelayed & scheduled;

traditionalPowerKW = ...
    traditionalLighting * powerKW(1) + ...
    traditionalFan * powerKW(2) + ...
    traditionalAC * powerKW(3) + ...
    traditionalMedia * powerKW(4);

smartPowerKW = ...
    smartLighting * powerKW(1) + ...
    smartFan * powerKW(2) + ...
    smartAC * powerKW(3) + ...
    smartMedia * powerKW(4);

traditionalDayKWh = sum(traditionalPowerKW) * stepMinutes / 60;
smartDayKWh = sum(smartPowerKW) * stepMinutes / 60;
savedDayKWh = traditionalDayKWh - smartDayKWh;
savedDayRatio = savedDayKWh / traditionalDayKWh;

fprintf('典型日传统控制用电：%.2f kWh\n', traditionalDayKWh);
fprintf('典型日节能控制用电：%.2f kWh\n', smartDayKWh);
fprintf('典型日节电量：%.2f kWh\n', savedDayKWh);
fprintf('典型日节电率：%.2f%%\n\n', savedDayRatio * 100);

simulationTable = table( ...
    timeHour, scheduled, occupied, outdoorTemperature, daylightLux, ...
    traditionalPowerKW, smartPowerKW, ...
    'VariableNames', { ...
    '时刻_h', '课表有效', '教室有人', '室外温度_C', '自然照度_lx', ...
    '传统控制功率_kW', '节能控制功率_kW'});
writetable(simulationTable, '典型日控制仿真数据.csv', 'Encoding', 'UTF-8');

figure('Color', 'w', 'Name', '典型日控制仿真');
tiledlayout(2, 1, 'TileSpacing', 'compact');

nexttile;
stairs(timeHour, double(scheduled), '--', 'LineWidth', 1.5);
hold on;
stairs(timeHour, double(occupied), 'LineWidth', 1.8);
ylim([-0.1, 1.2]);
xlim([0, 24]);
yticks([0, 1]);
yticklabels({'无', '有'});
xlabel('时刻 h');
ylabel('状态');
title('课表与实际占用状态');
legend('课表有效', '实际有人', 'Location', 'northwest');
grid on;

nexttile;
plot(timeHour, traditionalPowerKW, 'LineWidth', 1.7);
hold on;
plot(timeHour, smartPowerKW, 'LineWidth', 1.7);
xlim([0, 24]);
xlabel('时刻 h');
ylabel('功率 kW');
title(sprintf('节能前后负荷曲线  典型日节电率 %.1f%%', ...
    savedDayRatio * 100));
legend('传统控制', '节能控制', 'Location', 'northwest');
grid on;
exportgraphics(gcf, '典型日节能控制仿真.png', 'Resolution', 300);

%% 7 节电目标、费用、碳减排和回收期
annualSavingKWh = (45e4:5e4:65e4)';
annualSavingWanKWh = annualSavingKWh / 1e4;
annualBenefitYuan = annualSavingKWh * electricityPrice;
annualBenefitWanYuan = annualBenefitYuan / 1e4;
carbonReductionTon = annualSavingKWh * carbonFactor / 1000;
paybackYears = projectInvestment ./ annualBenefitYuan;

benefitTable = table( ...
    annualSavingWanKWh, annualBenefitWanYuan, ...
    carbonReductionTon, paybackYears, ...
    'VariableNames', { ...
    '年节电量_万kWh', '年电费收益_万元', ...
    '年碳减排量_吨', '静态回收期_年'});

disp('表 3  节能效益分析');
disp(benefitTable);
writetable(benefitTable, '节能效益分析.csv', 'Encoding', 'UTF-8');

figure('Color', 'w', 'Name', '节能效益');
yyaxis left;
bar(annualSavingWanKWh, annualBenefitWanYuan, 0.55, ...
    'FaceColor', [0.24, 0.58, 0.43]);
xlabel('年节电量 万kWh');
ylabel('年电费收益 万元');
yyaxis right;
plot(annualSavingWanKWh, paybackYears, '-o', ...
    'LineWidth', 2, 'MarkerSize', 7, 'Color', [0.75, 0.22, 0.17]);
ylabel('静态回收期 年');
title('节电目标与经济效益');
grid on;
exportgraphics(gcf, '节能效益分析.png', 'Resolution', 300);

%% 8 输出主要结论
fprintf('主要结论\n');
fprintf('1. 中位情景年用电量约 %.2f 万kWh。\n', totalEnergyKWh / 1e4);
fprintf('2. 非监管浪费约 %.2f 万kWh，占 %.2f%%。\n', ...
    totalWasteKWh / 1e4, overallWasteRatio * 100);
fprintf('3. 浪费电费约 %.2f 万元，对应 %.2f 吨CO2。\n', ...
    totalWasteCost / 1e4, totalWasteCarbonKg / 1000);
fprintf('4. 空调运行时间和空置运行比例是最敏感参数。\n');
fprintf('5. 年节电 45 至 65 万kWh 时，静态回收期约 %.1f 至 %.1f 年。\n', ...
    min(paybackYears), max(paybackYears));

