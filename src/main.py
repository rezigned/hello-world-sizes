import os
import sys
import re
from pathlib import Path
from datetime import datetime

import pandas as pd
import plotly.graph_objects as go
import plotly.express as px

NAMES = {
    "cpp": "c++",
}

class BinarySizeAnalyzer:
    def __init__(self, bin_dir: Path, system: str):
        self.workspace = Path.cwd()
        self.src_dir = self.workspace / "src"
        self.bin_dir = bin_dir
        self.system = system
        self.results_dir = self.workspace / "build/reports"
        self.results_dir.mkdir(parents=True, exist_ok=True)

        # Define a color palette for programming languages
        self.color_palette = px.colors.qualitative.Plotly

    def analyze_binaries(self) -> dict:
        """Analyze binary sizes and return results with timestamps."""
        results = {}

        for bin in os.listdir(self.bin_dir):
            out_file = self.bin_dir / bin

            # Normalize the file name
            #
            # "hello-asm" => "asm"
            # "hello-c-musl" => "c (musl)"
            _, lang, variant, *rest = (bin + '-').split('-')

            lang = NAMES.get(lang, lang)
            name = f"{lang} ({variant})" if variant else lang

            print(f"Analyzing {name}...")
            if out_file.exists():
                results[name] = {
                    "size": out_file.stat().st_size,
                    "timestamp": datetime.now().isoformat(sep=" ", timespec="seconds")
                }
        return results

    def visualize_results(self, results: dict):
        """Create and save visualizations of the binary sizes with color-coded languages."""
        if not results:
            print("No results to visualize.")
            return

        def format_lang(lang: str) -> str:
            """Format language name for display."""
            name, variant, *rest = (lang + ' ').split(' ')

            return f"{name}<br><span style='font-size:10px; color:#6b7280'>{variant}</span>"

        df = pd.DataFrame.from_dict(results, orient='index')
        df['size_kb'] = df['size'] / 1024
        df.sort_values('size_kb', inplace=True)

        # Assign colors to languages based on index
        colors = [self.color_palette[i % len(self.color_palette)] for i in range(len(df))]

        # Create bar chart with customized colors
        fig = go.Figure(go.Bar(
            x=df.index,
            y=df['size_kb'],
            marker_color=colors,
            hovertemplate="<b>%{x}</b><br>Size: %{y:.1f} KB<br><extra></extra>"
        ))

        fig.update_layout(
            title=dict(
                text='Binary Sizes of "Hello, World!" Programs',
                x=0.5,
                font=dict(size=24, color='#1f2937')
            ),
            plot_bgcolor='white',
            paper_bgcolor='white',
            xaxis=dict(
                title='Programming Language',
                tickfont_size=14,
                title_font_size=16,
                showgrid=False,
                tickmode='array',
                tickvals=list(range(len(df))),
                ticktext=[format_lang(lang) for lang in df.index]
            ),
            yaxis=dict(
                title='Binary Size (KB)',
                tickfont_size=14,
                title_font_size=16,
                gridcolor='#f3f4f6',
                showgrid=True,
            ),
            showlegend=False,
            margin=dict(t=100, l=70, r=40, b=120),
            height=600,
        )

        # Add size labels above each bar
        for idx, row in df.iterrows():
            fig.add_annotation(
                x=idx,
                y=row['size_kb'],
                text=f"{row['size_kb']:.1f}KB",
                yshift=10,
                showarrow=False,
                font=dict(size=12)
            )

        # Add metadata about system and date
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        fig.add_annotation(
            x=0.5,
            y=-0.25,
            xref="paper",
            yref="paper",
            text=f"System: {self.system} | Generated: {timestamp}",
            showarrow=False,
            font=dict(size=12, color="#6b7280")
        )

        # Save visual outputs
        html_path = self.results_dir / "binary_sizes.html"
        json_path = self.results_dir / "binary_sizes.json"
        png_path = self.results_dir / "binary_sizes.png"

        try:
            fig.write_html(html_path)
            fig.write_image(png_path, scale=2)
        except Exception as e:
            print(f"Warning: Failed to save PNG image: {e}")
            print("Saving HTML version only...")
            fig.write_html(html_path)

        # Save data with colors for reference
        df['color'] = colors
        df.to_json(json_path)

    def print_summary(self, results: dict):
        if not results:
            print("No binaries found.")
            return

        print("\nBinary sizes:")
        for lang, data in sorted(results.items(), key=lambda x: x[1]['size']):
            print(f"{lang}: {data['size'] / 1024:.1f} KB")

def main():
    if len(sys.argv) < 3:
        print("Usage: python script.py <bin_dir> <system>")
        sys.exit(1)

    bin_dir = Path(sys.argv[1])
    if not bin_dir.is_dir():
        print(f"Error: Provided path {bin_dir} is not a directory.")
        sys.exit(1)

    system = sys.argv[2]

    analyzer = BinarySizeAnalyzer(bin_dir, system)
    results = analyzer.analyze_binaries()
    analyzer.print_summary(results)
    analyzer.visualize_results(results)

    print(f"\nVisualizations of {system} binaries saved in:")
    print(f"- HTML: {analyzer.results_dir / 'binary_sizes.html'}")
    print(f"- PNG : {analyzer.results_dir / 'binary_sizes.png'}")
    print(f"- JSON: {analyzer.results_dir / 'binary_sizes.json'}")

if __name__ == "__main__":
    main()
