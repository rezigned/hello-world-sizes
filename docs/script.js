document.addEventListener('DOMContentLoaded', () => {
    const timestampSelect = document.getElementById('timestamp-select');
    const binarySizeChartCanvas = document.getElementById('binary-size-chart');
    const memoryUsageChartCanvas = document.getElementById('memory-usage-chart');

    let binarySizeChart;
    let memoryUsageChart;
    let availableTimestamps = [];
    let reportsCache = {};

    async function loadReports() {
        try {
            const response = await fetch('reports.json');
            if (!response.ok) {
                console.error('Could not load reports.json');
                return;
            }
            availableTimestamps = await response.json();
            populateTimestampSelector();
            renderCharts();
        } catch (error) {
            console.error('Error loading reports:', error);
        }
    }

    function populateTimestampSelector() {
        const latestOption = document.createElement('option');
        latestOption.value = 'latest';
        latestOption.textContent = 'Latest';
        timestampSelect.appendChild(latestOption);

        availableTimestamps.forEach(ts => {
            const option = document.createElement('option');
            option.value = ts;
            option.textContent = new Date(ts).toLocaleString();
            timestampSelect.appendChild(option);
        });

        timestampSelect.addEventListener('change', renderCharts);
    }

    async function renderCharts() {
        const selectedTimestamp = timestampSelect.value;

        let report = reportsCache[selectedTimestamp];
        if (!report) {
            try {
                const response = await fetch(`reports/${selectedTimestamp}.json`);
                if (!response.ok) {
                    throw new Error(`Could not load report: ${selectedTimestamp}`);
                }
                report = await response.json();
                reportsCache[selectedTimestamp] = report;
            } catch (error) {
                console.error(error);
                return;
            }
        }

        renderChart(binarySizeChartCanvas, 'binary_size', report.binary_size);
        renderChart(memoryUsageChartCanvas, 'memory_usage', report.memory_usage);
    }

    function renderChart(canvas, metric, data) {
        if (!data) return;

        // Initialize ECharts instance
        let chart = echarts.getInstanceByDom(canvas);
        if (!chart) {
            chart = echarts.init(canvas);
        }

        // Process data
        const langValues = {};
        data.forEach(d => {
            if (langValues[d.language] === undefined || d.value < langValues[d.language]) {
                langValues[d.language] = d.value;
            }
        });

        const languages = [...new Set(data.map(d => d.language))].sort((a, b) => {
            const valA = langValues[a];
            const valB = langValues[b];
            if (valA !== valB) return valA - valB;
            return a.localeCompare(b);
        });

        const amd64Data = [];
        const arm64Data = [];

        languages.forEach(lang => {
            const amd64Entry = data.find(d => d.language === lang && d.arch === 'amd64');
            const arm64Entry = data.find(d => d.language === lang && d.arch === 'arm64');

            amd64Data.push({
                value: amd64Entry ? amd64Entry.value : null,
                version: amd64Entry ? amd64Entry.version : '',
                lang: lang
            });
            arm64Data.push({
                value: arm64Entry ? arm64Entry.value : null,
                version: arm64Entry ? arm64Entry.version : '',
                lang: lang
            });
        });

        const yAxisName = metric === 'binary_size' ? 'Binary Size (KB)' : 'Resident Set Size (KB)';

        const option = {
            animation: false,
            textStyle: { fontFamily: 'Inter, sans-serif' },
            tooltip: {
                trigger: 'axis',
                axisPointer: { type: 'shadow' },
                backgroundColor: 'rgba(0, 0, 0, 0.8)',
                padding: 10,
                textStyle: { color: '#fff' },
                formatter: function (params) {
                    let tooltip = `<strong>${params[0].name}</strong><br/>`;
                    params.forEach(param => {
                        if (param.value !== null && param.value !== undefined) {
                            tooltip += `${param.marker} ${param.seriesName}: ${param.value.toFixed(1)} KB<br/>`;
                            if (param.data.version) {
                                tooltip += `<span style="opacity:0.7; font-size:12px; margin-left: 14px">Version: ${param.data.version}</span><br/>`;
                            }
                        }
                    });
                    return tooltip;
                }
            },
            legend: {
                top: 0,
                right: 0,
                itemGap: 20
            },
            grid: {
                left: '2%',
                right: '4%',
                bottom: '5%',
                top: '15%',
                containLabel: true
            },
            dataZoom: [
                {
                    type: 'slider',
                    show: false,
                    yAxisIndex: 0,
                    right: 10,
                    width: 20,
                    start: 0,
                    end: 100,
                    borderColor: 'transparent',
                    handleSize: '80%',
                    handleStyle: {
                        color: '#fff',
                        shadowBlur: 3,
                        shadowColor: 'rgba(0, 0, 0, 0.6)'
                    }
                },
                {
                    type: 'inside',
                    yAxisIndex: 0,
                    zoomOnMouseWheel: true,
                    moveOnMouseWheel: true
                }
            ],
            xAxis: {
                type: 'category',
                data: languages,
                axisLabel: {
                    rotate: 45,
                    interval: 0,
                    margin: 10,
                    color: '#4b5563',
                    formatter: function (value) {
                        const entry = data.find(d => d.language === value);
                        const version = entry ? entry.version : '';
                        return version ? `${value}\n${version}` : value;
                    },
                    lineHeight: 14
                },
                axisTick: { alignWithLabel: true }
            },
            yAxis: {
                type: 'value',
                name: yAxisName,
                nameLocation: 'end',
                nameTextStyle: {
                    padding: [0, 0, 10, 0],
                    color: '#4b5563',
                    fontWeight: 'bold'
                },
                splitLine: {
                    lineStyle: {
                        type: 'dashed',
                        color: '#e5e7eb'
                    }
                },
                axisLabel: {
                    color: '#4b5563',
                    formatter: '{value} KB'
                }
            },
            series: [
                {
                    name: 'amd64',
                    type: 'bar',
                    data: amd64Data,
                    itemStyle: { color: 'rgba(255, 99, 132, 0.6)', borderColor: 'rgba(255, 99, 132, 1)', borderWidth: 1 },
                    label: {
                        show: true,
                        position: 'top',
                        formatter: p => p.value ? p.value.toFixed(0) : '',
                        color: '#4b5563',
                        fontSize: 10
                    }
                },
                {
                    name: 'arm64',
                    type: 'bar',
                    data: arm64Data,
                    itemStyle: { color: 'rgba(54, 162, 235, 0.6)', borderColor: 'rgba(54, 162, 235, 1)', borderWidth: 1 },
                    label: {
                        show: true,
                        position: 'top',
                        formatter: p => p.value ? p.value.toFixed(0) : '',
                        color: '#4b5563',
                        fontSize: 10
                    }
                }
            ]
        };

        chart.setOption(option);

        // Handle window resize
        window.removeEventListener('resize', chart.__resizeHandler);
        window.addEventListener('resize', chart.__resizeHandler);
        chart.__resizeHandler = () => chart.resize();
    }

    // Wait for fonts to be ready before rendering to avoid font snapping
    document.fonts.ready.then(() => {
        loadReports();
    });
});
