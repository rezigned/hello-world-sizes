import os
import sys
import re
import subprocess

from abc import ABC, abstractmethod
from pathlib import Path
from datetime import datetime

import pandas as pd
import plotly.graph_objects as go
import plotly.express as px

class Metric(ABC):
    """Abstract base class for different measurement metrics."""

    @abstractmethod
    def name(self) -> str:
        """Return the name of the metric."""
        pass

    @abstractmethod
    def title(self) -> str:
        """Return the title for visualization."""
        pass

    @abstractmethod
    def y_axis_label(self) -> str:
        """Return the y-axis label for visualization."""
        pass

    @abstractmethod
    def measure(self, bin_path: Path) -> float:
        """Measure the metric for a given binary."""
        pass

class BinarySizeMetric(Metric):
    """Metric for measuring binary file sizes."""

    def name(self) -> str:
        return "binary_size"

    def title(self) -> str:
        return 'Binary Sizes of "Hello, World!" Programs'

    def y_axis_label(self) -> str:
        return "Binary Size (KB)"

    def measure(self, bin_path: Path) -> float:
        """Measure the file size of a binary in kilobytes."""
        return bin_path.stat().st_size / 1024

class MemoryUsageMetric(Metric):
    """Metric for measuring RSS memory usage."""

    def name(self) -> str:
        return "memory_usage"

    def title(self) -> str:
        return 'Memory Usage of "Hello, World!" Programs'

    def y_axis_label(self) -> str:
        return "Resident Set Size (KB)"

    def measure(self, bin_path: Path) -> float:
        """Measure the RSS memory usage of a binary in kilobytes."""
        try:
            # Run the program with time to capture memory usage
            result = subprocess.run(
                ["time", "-v", str(bin_path)],
                capture_output=True,
                text=True,
                check=False
            )

            # Extract memory information from stderr output
            stderr_output = result.stderr

            # Parse RSS from time output
            rss_match = re.search(r'Maximum resident set size \(kbytes\): (\d+)', stderr_output)
            rss = float(rss_match.group(1)) if rss_match else 0

            return rss
        except Exception as e:
            print(f"Error measuring memory for {bin_path}: {e}")
            return 0.0

NAMES = {
    "cpp": "c++",
}

METRICS = {
    "size": BinarySizeMetric(),
    "mem": MemoryUsageMetric(),
}

OUTPUTS = ["html", "json", "png"]

class BinaryAnalyzer:
    """Analyzer for different performance metrics of programs."""

    def __init__(self, bin_dir: Path, metric: Metric, system: str):
        self.workspace = Path.cwd()
        self.src_dir = self.workspace / "src"
        self.bin_dir = bin_dir
        self.system = system
        self.metric = metric
        self.results_dir = self.workspace / "build/reports"
        self.results_dir.mkdir(parents=True, exist_ok=True)

        # Define a color palette for programming languages
        self.color_palette = px.colors.qualitative.Plotly

    def analyze_binaries(self) -> dict:
        """Analyze programs using the selected metric and return results with timestamps."""
        results = {}

        for bin_name in os.listdir(self.bin_dir):
            if bin_name.endswith(".version"):
                continue

            bin_path = self.bin_dir / bin_name

            # Normalize the file name
            #
            # "hello-asm" => "asm"
            # "hello-c-musl" => "c (musl)"
            _, lang, variant, *rest = (bin_name + '-').split('-')

            lang = NAMES.get(lang.lower(), lang)
            name = f"{lang} ({variant})" if variant else lang

            print(f"Analyzing {name}...")

            if bin_path.exists():
                metric_value = self.metric.measure(bin_path)

                # Try to read version info
                version = ""
                version_path = bin_path.parent / (bin_name + ".version")
                if version_path.exists():
                    try:
                        # Take the first line and trim it
                        raw_version = version_path.read_text().splitlines()[0].strip()
                        # Heuristics to shorten common version strings
                        # e.g. "go version go1.24.0 linux/amd64" -> "1.24.0"
                        if raw_version.startswith("go version"):
                            version = raw_version.split(" ")[2].replace("go", "")
                        # e.g. "rustc 1.77.2 (25ef9e3d8 2024-04-09)" -> "1.77.2"
                        elif raw_version.startswith("rustc"):
                             version = raw_version.split(" ")[1]
                        # e.g. "gcc (GCC) 13.2.0" -> "13.2.0"
                        elif " (GCC) " in raw_version:
                             version = raw_version.split(" (GCC) ")[1].split(" ")[0]
                        # e.g. "Free Software Foundation ... nasm version 2.16.01" -> "2.16.01"
                        elif "NASM version" in raw_version:
                             version = raw_version.split("NASM version")[1].strip().split(" ")[0]
                        # e.g. "Nim Compiler Version 2.0.0" -> "2.0.0"
                        elif "Nim Compiler Version" in raw_version:
                             version = raw_version.split("Version")[1].strip().split(" ")[0]
                        # e.g. "V 0.4.5" -> "0.4.5"
                        elif raw_version.startswith("V ") and any(c.isdigit() for c in raw_version):
                             version = raw_version.split(" ")[1]
                        # e.g. "Crystal 1.12.1"
                        elif raw_version.startswith("Crystal "):
                             version = raw_version.split(" ")[1]
                        # e.g. "odin version dev-2024-11" -> "dev-2024-11"
                        elif raw_version.startswith("odin version"):
                             version = raw_version.replace("odin version", "").strip().split(" ")[0]
                        else:
                             # Fallback: take first 2 words or 20 chars
                             version = " ".join(raw_version.split()[:2])[:20]
                    except Exception as e:
                        print(f"Failed to read version for {bin_name}: {e}")

                results[name] = {
                    "value": metric_value,
                    "timestamp": datetime.now().isoformat(sep=" ", timespec="seconds"),
                    "version": version
                }

        return results

    def visualize_results(self, results: dict):
        """Create and save visualizations of the results with color-coded languages."""
        if not results:
            print("No results to visualize.")
            return

        def format_lang(lang: str) -> str:
            """Format language name for display."""
            # Parsing name/variant
            if " (" in lang:
                name = lang.split(" (")[0]
                variant = lang.split(" (")[1].replace(")", "")
            else:
                name = lang
                variant = ""

            ver = results[lang].get("version", "")
            label = f"<b>{name}</b>"

            # Version goes second
            if ver:
                label += f"<br><span style='font-size:10px; color:#555'>{ver}</span>"
            # Variant (libc) goes last
            if variant:
                label += f"<br><span style='font-size:10px; color:#555'>({variant})</span>"
            return label

        df = pd.DataFrame.from_dict(results, orient='index')
        df.sort_values('value', inplace=True)

        # Assign colors to languages based on index
        colors = [self.color_palette[i % len(self.color_palette)] for i in range(len(df))]

        # Create bar chart with customized colors
        fig = go.Figure(go.Bar(
            x=df.index,
            y=df['value'],
            marker_color=colors,
            hovertemplate="<b>%{x}</b><br>Value: %{y:.1f} KB<br><extra></extra>"
        ))

        fig.update_layout(
            title=dict(
                text=f"{self.metric.title()}<br><span style='font-size:18px; color:#6b7280'>({self.system})</span>",
                x=0.5,
                font=dict(size=24, color='#1f2937')
            ),
            plot_bgcolor='white',
            paper_bgcolor='white',
            xaxis=dict(
                title='Programming Language',
                tickfont_size=12,
                title_font_size=16,
                showgrid=False,
                tickmode='array',
                tickvals=list(range(len(df))),
                ticktext=[format_lang(lang) for lang in df.index]
            ),
            yaxis=dict(
                title=self.metric.y_axis_label(),
                tickfont_size=13,
                title_font_size=16,
                gridcolor='#f3f4f6',
                showgrid=True,
            ),
            showlegend=False,
            margin=dict(t=100, l=70, r=40, b=180),
            height=600,
        )

        # Add value labels above each bar
        for idx, row in df.iterrows():
            fig.add_annotation(
                x=idx,
                y=row['value'],
                text=f"{row['value']:.1f}KB",
                yshift=10,
                showarrow=False,
                font=dict(size=12)
            )

        # Add metadata about system and date
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        fig.add_annotation(
            x=0.5,
            y=-0.35, # Moved further down to avoid overlap
            xref="paper",
            yref="paper",
            text=f"System: {self.system} | Metric: {self.metric.name()} | Generated: {timestamp}",
            showarrow=False,
            font=dict(size=11, color="#6b7280")
        )

        # Save visual outputs
        output_prefix = self.metric.name()
        html_path = self.results_dir / f"{output_prefix}.html"
        json_path = self.results_dir / f"{output_prefix}.json"
        png_path = self.results_dir / f"{output_prefix}.png"

        try:
            fig.write_html(html_path)
            fig.write_image(png_path, scale=2)
        except Exception as e:
            print(f"Warning: Failed to save PNG image: {e}")
            print("Saving HTML version only...")
            fig.write_html(html_path)

        # Save data as a list of records
        df.reset_index(inplace=True)
        df.rename(columns={'index': 'language'}, inplace=True)
        records = df.to_dict(orient='records')
        
        with open(json_path, 'w') as f:
            import json
            json.dump(records, f, indent=4)

    def print_summary(self, results: dict):
        if not results:
            print("No programs found to analyze.")
            return

        print(f"\n{self.metric.y_axis_label()}:")
        for lang, data in sorted(results.items(), key=lambda x: x[1]['value']):
            ver_str = f" ({data.get('version', '')})" if data.get('version') else ""
            print(f"{lang}{ver_str}: {data['value']:.1f} KB")

def main():
    if len(sys.argv) < 4:
        print("Usage: python main.py <bin_dir> <metric> <system>")
        print("Metric: size, mem")
        sys.exit(1)

    bin_dir = Path(sys.argv[1])
    if not bin_dir.is_dir():
        print(f"Error: Provided path {bin_dir} is not a directory.")
        sys.exit(1)

    metric = METRICS.get(sys.argv[2])
    if not metric:
        print(f"Error: Invalid metric '{metric}'. Available metrics: {', '.join(METRICS.keys())}")
        sys.exit(1)

    # System information
    system = sys.argv[3]

    # Run analysis
    analyzer = BinaryAnalyzer(bin_dir, metric, system)
    results = analyzer.analyze_binaries()
    analyzer.print_summary(results)
    analyzer.visualize_results(results)

    print(f"\nVisualizations of {system} binaries saved in:")
    for fmt in OUTPUTS:
        print(f"- {fmt.upper()}: {analyzer.results_dir / (metric.name() + '.' + fmt)}")

if __name__ == "__main__":
    main()
