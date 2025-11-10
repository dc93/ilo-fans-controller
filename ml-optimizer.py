#!/usr/bin/env python3
"""
Machine Learning Fan Optimization for iLO Fans Controller

This script analyzes historical temperature and fan speed data to:
- Learn optimal fan curves for your specific workload
- Predict temperature trends
- Suggest more efficient fan profiles
- Detect anomalies and potential issues

Requirements:
    pip install numpy pandas scikit-learn matplotlib requests

Usage:
    python3 ml-optimizer.py --analyze
    python3 ml-optimizer.py --optimize
    python3 ml-optimizer.py --predict
    python3 ml-optimizer.py --train
"""

import argparse
import json
import os
import sys
from datetime import datetime, timedelta
from typing import Dict, List, Tuple, Optional

try:
    import numpy as np
    import pandas as pd
    from sklearn.linear_model import LinearRegression
    from sklearn.preprocessing import PolynomialFeatures
    from sklearn.cluster import KMeans
    import requests
except ImportError:
    print("ERROR: Required packages not installed.")
    print("Install with: pip install numpy pandas scikit-learn matplotlib requests")
    sys.exit(1)

# Configuration
ILO_API_URL = os.getenv('ILO_API_URL', 'http://localhost:8000/index.php')
DATA_FILE = '/var/www/html/ilo-fans-controller/data/history.json'
MODEL_FILE = '/var/www/html/ilo-fans-controller/data/ml_model.json'


class FanOptimizer:
    """Machine Learning optimizer for fan speed control"""

    def __init__(self):
        self.data = None
        self.model = None
        self.temperature_sensors = []
        self.fan_names = []

    def load_historical_data(self, days=7) -> pd.DataFrame:
        """Load historical data from API or file"""
        print(f"Loading {days} days of historical data...")

        try:
            # Try API first
            response = requests.get(f"{ILO_API_URL}?api=history&range={days}d", timeout=10)
            data = response.json()
        except Exception as e:
            print(f"API error: {e}")
            # Fallback to file
            if os.path.exists(DATA_FILE):
                with open(DATA_FILE, 'r') as f:
                    data = json.load(f)
            else:
                print("ERROR: No data available")
                return pd.DataFrame()

        # Convert to DataFrame
        records = []
        for entry in data:
            record = {
                'timestamp': pd.to_datetime(entry['timestamp'], unit='s'),
                'hour': pd.to_datetime(entry['timestamp'], unit='s').hour,
                'day_of_week': pd.to_datetime(entry['timestamp'], unit='s').dayofweek,
            }

            # Add fan speeds
            if 'fans' in entry:
                for fan, speed in entry['fans'].items():
                    record[f'fan_{fan}'] = speed
                    if fan not in self.fan_names:
                        self.fan_names.append(fan)

            # Add temperatures
            if 'temperatures' in entry:
                for temp in entry['temperatures']:
                    sensor_name = temp['name'].replace(' ', '_')
                    record[f'temp_{sensor_name}'] = temp['value']
                    if sensor_name not in self.temperature_sensors:
                        self.temperature_sensors.append(sensor_name)

            records.append(record)

        df = pd.DataFrame(records)
        print(f"Loaded {len(df)} data points")
        print(f"Sensors: {', '.join(self.temperature_sensors)}")
        print(f"Fans: {', '.join(self.fan_names)}")

        self.data = df
        return df

    def analyze_patterns(self) -> Dict:
        """Analyze patterns in temperature and fan speed data"""
        if self.data is None or self.data.empty:
            return {}

        print("\n=== PATTERN ANALYSIS ===\n")

        analysis = {
            'temperature_stats': {},
            'fan_stats': {},
            'correlations': {},
            'time_patterns': {},
            'recommendations': []
        }

        # Temperature statistics
        for sensor in self.temperature_sensors:
            col = f'temp_{sensor}'
            if col in self.data.columns:
                analysis['temperature_stats'][sensor] = {
                    'mean': float(self.data[col].mean()),
                    'min': float(self.data[col].min()),
                    'max': float(self.data[col].max()),
                    'std': float(self.data[col].std())
                }

        # Fan statistics
        for fan in self.fan_names:
            col = f'fan_{fan}'
            if col in self.data.columns:
                analysis['fan_stats'][fan] = {
                    'mean': float(self.data[col].mean()),
                    'min': float(self.data[col].min()),
                    'max': float(self.data[col].max()),
                    'std': float(self.data[col].std())
                }

        # Correlation analysis
        for sensor in self.temperature_sensors:
            temp_col = f'temp_{sensor}'
            if temp_col not in self.data.columns:
                continue

            for fan in self.fan_names:
                fan_col = f'fan_{fan}'
                if fan_col not in self.data.columns:
                    continue

                corr = self.data[temp_col].corr(self.data[fan_col])
                key = f'{sensor}_vs_{fan}'
                analysis['correlations'][key] = float(corr)

        # Time-based patterns
        hourly_avg_temp = self.data.groupby('hour')[[f'temp_{s}' for s in self.temperature_sensors if f'temp_{s}' in self.data.columns]].mean()
        analysis['time_patterns']['hourly_temperature'] = hourly_avg_temp.to_dict()

        # Generate recommendations
        analysis['recommendations'] = self.generate_recommendations(analysis)

        return analysis

    def generate_recommendations(self, analysis: Dict) -> List[str]:
        """Generate optimization recommendations based on analysis"""
        recommendations = []

        # Check for over-cooling
        for sensor, stats in analysis['temperature_stats'].items():
            if stats['mean'] < 50:
                recommendations.append(
                    f"⚡ {sensor} averages {stats['mean']:.1f}°C - you may be over-cooling. "
                    f"Consider reducing fan speeds to save power and reduce noise."
                )

        # Check for under-cooling
        for sensor, stats in analysis['temperature_stats'].items():
            if stats['mean'] > 70:
                recommendations.append(
                    f"🔥 {sensor} averages {stats['mean']:.1f}°C - consider increasing fan speeds "
                    f"or improving airflow for better cooling."
                )

        # Check for inefficient fan usage
        for fan, stats in analysis['fan_stats'].items():
            if stats['std'] < 5:
                recommendations.append(
                    f"💡 {fan} speed varies little (±{stats['std']:.1f}%) - "
                    f"consider using PID control for dynamic adjustment."
                )

        # Check for high variation
        for sensor, stats in analysis['temperature_stats'].items():
            if stats['std'] > 10:
                recommendations.append(
                    f"📊 {sensor} shows high variation (±{stats['std']:.1f}°C) - "
                    f"this could indicate inconsistent workload or inadequate cooling response."
                )

        return recommendations

    def train_prediction_model(self) -> Dict:
        """Train ML model to predict optimal fan speeds"""
        if self.data is None or self.data.empty:
            print("ERROR: No data to train on")
            return {}

        print("\n=== TRAINING PREDICTION MODEL ===\n")

        models = {}

        # Train a model for each fan
        for fan in self.fan_names:
            fan_col = f'fan_{fan}'
            if fan_col not in self.data.columns:
                continue

            # Features: temperatures, hour, day of week
            feature_cols = [f'temp_{s}' for s in self.temperature_sensors if f'temp_{s}' in self.data.columns]
            feature_cols.extend(['hour', 'day_of_week'])

            X = self.data[feature_cols].values
            y = self.data[fan_col].values

            # Remove NaN values
            mask = ~np.isnan(X).any(axis=1) & ~np.isnan(y)
            X = X[mask]
            y = y[mask]

            if len(X) < 10:
                print(f"Insufficient data for {fan}")
                continue

            # Polynomial features for non-linear relationships
            poly = PolynomialFeatures(degree=2, include_bias=False)
            X_poly = poly.fit_transform(X)

            # Train model
            model = LinearRegression()
            model.fit(X_poly, y)

            score = model.score(X_poly, y)
            print(f"{fan}: R² = {score:.3f}")

            models[fan] = {
                'coefficients': model.coef_.tolist(),
                'intercept': float(model.intercept_),
                'features': feature_cols,
                'score': float(score),
                'poly_degree': 2
            }

        # Save model
        with open(MODEL_FILE, 'w') as f:
            json.dump(models, f, indent=2)

        print(f"\nModel saved to {MODEL_FILE}")
        return models

    def optimize_fan_speeds(self) -> Dict:
        """Suggest optimized fan speed profiles"""
        if self.data is None or self.data.empty:
            return {}

        print("\n=== OPTIMIZING FAN PROFILES ===\n")

        # Use K-means clustering to find common operating modes
        temp_cols = [f'temp_{s}' for s in self.temperature_sensors if f'temp_{s}' in self.data.columns]
        X = self.data[temp_cols].values

        # Remove NaN
        mask = ~np.isnan(X).any(axis=1)
        X_clean = X[mask]

        if len(X_clean) < 3:
            print("Insufficient data for optimization")
            return {}

        # Find 3 profiles: low, medium, high load
        kmeans = KMeans(n_clusters=3, random_state=42, n_init=10)
        clusters = kmeans.fit_predict(X_clean)

        # Get average temperatures and fan speeds for each cluster
        profiles = {}
        for i in range(3):
            cluster_mask = clusters == i
            cluster_data = self.data[mask].iloc[cluster_mask]

            avg_temps = {}
            avg_fans = {}

            for sensor in self.temperature_sensors:
                col = f'temp_{sensor}'
                if col in cluster_data.columns:
                    avg_temps[sensor] = float(cluster_data[col].mean())

            for fan in self.fan_names:
                col = f'fan_{fan}'
                if col in cluster_data.columns:
                    avg_fans[fan] = int(cluster_data[col].mean())

            # Classify profile
            max_temp = max(avg_temps.values()) if avg_temps else 0
            if max_temp < 55:
                profile_name = "quiet"
            elif max_temp < 65:
                profile_name = "balanced"
            else:
                profile_name = "performance"

            profiles[profile_name] = {
                'temperatures': avg_temps,
                'fan_speeds': avg_fans,
                'sample_size': int(cluster_mask.sum())
            }

            print(f"{profile_name.upper()} Profile:")
            print(f"  Avg temperature: {max_temp:.1f}°C")
            print(f"  Fan speeds: {avg_fans}")
            print(f"  Based on {cluster_mask.sum()} samples\n")

        return profiles

    def predict_next_hour(self) -> Dict:
        """Predict temperature trends for the next hour"""
        if self.data is None or self.data.empty:
            return {}

        print("\n=== TEMPERATURE PREDICTION ===\n")

        predictions = {}

        for sensor in self.temperature_sensors:
            col = f'temp_{sensor}'
            if col not in self.data.columns:
                continue

            # Use last 24 hours of data
            recent = self.data.tail(24)
            X = np.arange(len(recent)).reshape(-1, 1)
            y = recent[col].values

            # Remove NaN
            mask = ~np.isnan(y)
            X_clean = X[mask]
            y_clean = y[mask]

            if len(X_clean) < 3:
                continue

            # Fit trend
            model = LinearRegression()
            model.fit(X_clean, y_clean)

            # Predict next value
            next_temp = model.predict([[len(recent)]])[0]
            trend = "increasing" if model.coef_[0] > 0.1 else "decreasing" if model.coef_[0] < -0.1 else "stable"

            predictions[sensor] = {
                'current': float(y_clean[-1]),
                'predicted_1h': float(next_temp),
                'trend': trend,
                'rate': float(model.coef_[0])
            }

            print(f"{sensor}:")
            print(f"  Current: {y_clean[-1]:.1f}°C")
            print(f"  Predicted (+1h): {next_temp:.1f}°C")
            print(f"  Trend: {trend} ({model.coef_[0]:+.2f}°C/sample)\n")

        return predictions


def main():
    parser = argparse.ArgumentParser(description='ML-powered fan optimization')
    parser.add_argument('--analyze', action='store_true', help='Analyze patterns')
    parser.add_argument('--optimize', action='store_true', help='Generate optimized profiles')
    parser.add_argument('--predict', action='store_true', help='Predict temperature trends')
    parser.add_argument('--train', action='store_true', help='Train prediction model')
    parser.add_argument('--days', type=int, default=7, help='Days of data to analyze (default: 7)')
    parser.add_argument('--output', type=str, help='Output file for results (JSON)')

    args = parser.parse_args()

    if not any([args.analyze, args.optimize, args.predict, args.train]):
        parser.print_help()
        return

    optimizer = FanOptimizer()
    optimizer.load_historical_data(days=args.days)

    results = {}

    if args.analyze:
        results['analysis'] = optimizer.analyze_patterns()

        if results['analysis'].get('recommendations'):
            print("\n=== RECOMMENDATIONS ===\n")
            for rec in results['analysis']['recommendations']:
                print(f"  • {rec}")
            print()

    if args.optimize:
        results['profiles'] = optimizer.optimize_fan_speeds()

    if args.predict:
        results['predictions'] = optimizer.predict_next_hour()

    if args.train:
        results['model'] = optimizer.train_prediction_model()

    # Save results
    if args.output:
        with open(args.output, 'w') as f:
            json.dump(results, f, indent=2)
        print(f"Results saved to {args.output}")


if __name__ == '__main__':
    main()
