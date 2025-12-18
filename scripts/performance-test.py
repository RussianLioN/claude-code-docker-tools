#!/usr/bin/env python3
"""
Скрипт для тестирования производительности запуска контейнеров
"""

import time
import subprocess
import statistics

def main():
    times = []
    for i in range(5):
        start = time.time() * 1000
        subprocess.run(['gexec', 'echo test'], capture_output=True)
        end = time.time() * 1000
        times.append(end - start)

    avg_time = statistics.mean(times)
    print(f'Average container startup: {avg_time:.0f}ms')

    if avg_time > 5000:
        print('❌ Performance target missed (>5000ms)')
        exit(1)
    else:
        print('✅ Performance target met (<5000ms)')

if __name__ == "__main__":
    main()
