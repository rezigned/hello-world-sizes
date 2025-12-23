document.addEventListener('DOMContentLoaded', () => {
    Chart.defaults.font.family = "'Inter', system-ui, -apple-system, sans-serif";
    Chart.defaults.color = '#4b5563';

    const timestampSelect = document.getElementById('timestamp-select');
    const binarySizeChartCanvas = document.getElementById('binary-size-chart');
    const memoryUsageChartCanvas = document.getElementById('memory-usage-chart');

    let binarySizeChart;
    let memoryUsageChart;
    let reportsData = {};

    async function loadReports() {
        try {
            const response = await fetch('reports.json');
            if (!response.ok) {
                console.error('Could not load reports.json');
                return;
            }
            reportsData = await response.json();
            populateTimestampSelector();
            renderCharts();
        } catch (error) {
            console.error('Error loading reports:', error);
        }
    }

    function populateTimestampSelector() {
        const timestamps = Object.keys(reportsData).filter(key => key !== 'latest').sort().reverse();

        const latestOption = document.createElement('option');
        latestOption.value = 'latest';
        latestOption.textContent = 'Latest';
        timestampSelect.appendChild(latestOption);

        timestamps.forEach(ts => {
            const option = document.createElement('option');
            console.log({ ts })
            option.value = ts;
            option.textContent = new Date(ts).toLocaleString();
            timestampSelect.appendChild(option);
        });

        timestampSelect.addEventListener('change', renderCharts);
    }

    function renderCharts() {
        const selectedTimestamp = timestampSelect.value;
        const report = reportsData[selectedTimestamp];

        if (!report) {
            console.error(`No data for timestamp: ${selectedTimestamp}`);
            return;
        }

        binarySizeChart = renderChart(binarySizeChart, binarySizeChartCanvas, 'binary_size', report.binary_size);
        memoryUsageChart = renderChart(memoryUsageChart, memoryUsageChartCanvas, 'memory_usage', report.memory_usage);
    }

    function renderChart(chart, canvas, metric, data) {
        if (!data) {
            console.error(`No data for metric: ${metric}`);
            return;
        }

        // Calculate minimal value for each language to sort by smallest size first
        const langValues = {};
        data.forEach(d => {
            if (langValues[d.language] === undefined || d.value < langValues[d.language]) {
                langValues[d.language] = d.value;
            }
        });

        const languages = [...new Set(data.map(d => d.language))].sort((a, b) => {
            // Sort by value (ascending), then alphabetically if equal
            const valA = langValues[a];
            const valB = langValues[b];
            if (valA !== valB) return valA - valB;
            return a.localeCompare(b);
        });
        const amd64Data = [];
        const arm64Data = [];

        const labels = languages.map(lang => {
            const entry = data.find(d => d.language === lang);
            const version = entry ? entry.version : '';
            return [lang, version];
        });

        languages.forEach(lang => {
            const amd64Entry = data.find(d => d.language === lang && d.arch === 'amd64');
            const arm64Entry = data.find(d => d.language === lang && d.arch === 'arm64');
            amd64Data.push(amd64Entry ? amd64Entry.value : null);
            arm64Data.push(arm64Entry ? arm64Entry.value : null);
        });

        const datasets = [
            {
                label: 'amd64',
                data: amd64Data,
                backgroundColor: 'rgba(255, 99, 132, 0.5)',
                borderColor: 'rgba(255, 99, 132, 1)',
                borderWidth: 1
            },
            {
                label: 'arm64',
                data: arm64Data,
                backgroundColor: 'rgba(54, 162, 235, 0.5)',
                borderColor: 'rgba(54, 162, 235, 1)',
                borderWidth: 1
            }
        ];

        const yAxisLabel = metric === 'binary_size' ? 'Binary Size (KB)' : 'Resident Set Size (KB)';

        if (chart) {
            chart.data.labels = labels;
            chart.data.datasets = datasets;
            chart.options.scales.y.title.text = yAxisLabel;
            chart.update();
        } else {
            const ctx = canvas.getContext('2d');
            chart = new Chart(ctx, {
                type: 'bar',
                data: {
                    labels: labels,
                    datasets: datasets
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        legend: {
                            position: 'top',
                            align: 'end',
                            labels: {
                                boxWidth: 12,
                                padding: 20
                            }
                        },
                        tooltip: {
                            backgroundColor: 'rgba(0, 0, 0, 0.8)',
                            padding: 10,
                            callbacks: {
                                title: function (context) {
                                    // Use dataIndex to get the original language string
                                    return languages[context[0].dataIndex];
                                },
                                label: function (context) {
                                    let label = context.dataset.label || '';
                                    if (label) {
                                        label += ': ';
                                    }
                                    if (context.parsed.y !== null) {
                                        label += context.parsed.y.toFixed(1) + ' KB';
                                    }
                                    return label;
                                },
                                afterLabel: function (context) {
                                    const lang = languages[context.dataIndex];
                                    const entry = data.find(d => d.language === lang && d.arch === context.dataset.label);
                                    if (entry) {
                                        return 'Version: ' + entry.version;
                                    }
                                    return '';
                                }
                            }
                        }
                    },
                    scales: {
                        x: {
                            grid: {
                                display: false
                            }
                        },
                        y: {
                            beginAtZero: true,
                            grid: {
                                borderDash: [2, 4],
                                color: '#e5e7eb'
                            },
                            title: {
                                display: true,
                                text: yAxisLabel
                            }
                        }
                    }
                }
            });
        }
        return chart;
    }

    loadReports();
});
