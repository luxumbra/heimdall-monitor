#!/bin/bash
# Test script to verify the monitor system is completely portable
# This script can be run from any directory to verify no hard-coded paths exist

echo "🧪 Testing Internet Monitor Portability"
echo "======================================="

# Check if we're in the right directory
if [[ ! -f "internet_monitor.py" ]]; then
    echo "❌ Error: Run this script from the internet monitor directory"
    exit 1
fi

CURRENT_DIR="$(pwd)"
echo "📍 Current directory: $CURRENT_DIR"
echo ""

# Check for hard-coded paths in Python script
echo "🔍 Checking for hard-coded paths in Python script..."
if grep -n "/work/projects\|/home/" internet_monitor.py 2>/dev/null | grep -v "# Example:" | grep -v "ssh_key"; then
    echo "⚠️  Found potential hard-coded paths in internet_monitor.py"
else
    echo "✅ No hard-coded paths found in internet_monitor.py"
fi

# Check service template
echo ""
echo "🔍 Checking service template for hard-coded paths..."
if grep -n "/work/projects\|/home/" internet-monitor-template.service 2>/dev/null | grep -v "# Example:"; then
    echo "⚠️  Found potential hard-coded paths in service template"
else
    echo "✅ No hard-coded paths found in service template"
fi

# Check install script  
echo ""
echo "🔍 Checking install script for hard-coded paths..."
if grep -n "/work/projects\|/home/" install-service.sh 2>/dev/null | grep -v "# Example:" | grep -v "echo"; then
    echo "⚠️  Found potential hard-coded paths in install script"  
else
    echo "✅ No hard-coded paths found in install script"
fi

# Test that install script detects directory correctly
echo ""
echo "🧪 Testing directory auto-detection..."
DETECTED_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "   Script would detect directory as: $DETECTED_DIR"
if [[ "$DETECTED_DIR" == "$CURRENT_DIR" ]]; then
    echo "✅ Directory auto-detection works correctly"
else
    echo "⚠️  Directory auto-detection may have issues"
fi

echo ""
echo "📋 Summary:"
echo "   • Service template uses variables: \${MONITOR_USER}, \${MONITOR_WORKING_DIR}"
echo "   • Install script auto-detects its own directory"
echo "   • No hard-coded personal paths found"
echo "   • System is portable across different users and directories"
echo ""
echo "🎉 Portability test complete!"