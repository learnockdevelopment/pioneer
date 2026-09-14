import sys

with open(r'c:\Users\dell\apps\apps\Learnock-DRM-\lib\screens\dashboard_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Find the second implementation of _showPremiumAlert
# It starts around line 1127
new_lines = lines[:1125]
new_lines.append('}\n')

with open(r'c:\Users\dell\apps\apps\Learnock-DRM-\lib\screens\dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print("Fixed DashboardScreen.dart")
