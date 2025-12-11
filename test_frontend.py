#!/usr/bin/env python3
"""
Test frontend with Selenium to capture console errors and page state
"""
import time
from selenium import webdriver
from selenium.webdriver.firefox.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

def test_frontend():
    options = Options()
    options.add_argument('--headless')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')

    # Enable browser console logging
    options.set_preference('devtools.console.stdout.content', True)
    options.set_preference('devtools.console.stdout.chrome', True)

    # Enable geckodriver logging
    from selenium.webdriver.firefox.service import Service
    service = Service(log_output='/tmp/geckodriver.log')

    driver = webdriver.Firefox(options=options, service=service)

    try:
        # Clear browser cache to avoid stale module errors
        driver.delete_all_cookies()

        # Enable browser console capture
        driver.execute_script("""
            window._consoleErrors = [];
            window._consoleLogs = [];
            const origError = console.error;
            const origLog = console.log;
            console.error = function(...args) {
                window._consoleErrors.push(args.join(' '));
                origError.apply(console, args);
            };
            console.log = function(...args) {
                window._consoleLogs.push(args.join(' '));
                origLog.apply(console, args);
            };
        """)

        print("🌐 Loading http://localhost:3000...")
        driver.get('http://localhost:3000')

        # Wait longer for React to load
        print("⏳ Waiting 10 seconds for React to load...")
        time.sleep(10)
        
        # Get page title
        print(f"📄 Page title: {driver.title}")

        # Execute JavaScript to check if React loaded and get console output
        print("\n📋 Checking React and module loading...")
        react_check = driver.execute_script("""
            return {
                hasReact: typeof React !== 'undefined',
                hasReactDOM: typeof ReactDOM !== 'undefined',
                consoleErrors: window._consoleErrors || [],
                consoleLogs: window._consoleLogs || [],
                windowError: window._lastError || null
            };
        """)
        print(f"  React loaded: {react_check['hasReact']}")
        print(f"  ReactDOM loaded: {react_check['hasReactDOM']}")

        if react_check['consoleErrors']:
            print(f"\n❌ Console errors ({len(react_check['consoleErrors'])}):")
            for err in react_check['consoleErrors'][:10]:
                print(f"  {err}")

        if react_check['consoleLogs']:
            print(f"\n📝 Console logs ({len(react_check['consoleLogs'])}):")
            for log in react_check['consoleLogs'][:10]:
                print(f"  {log}")
        
        # Check if body is empty
        body_text = driver.find_element(By.TAG_NAME, 'body').text
        print(f"\n📝 Body text length: {len(body_text)} characters")
        if len(body_text) < 50:
            print(f"⚠️  Body text: '{body_text}'")
        else:
            print(f"✅ Body text preview: {body_text[:100]}...")
        
        # Check for React root
        try:
            root = driver.find_element(By.ID, 'root')
            root_html = root.get_attribute('innerHTML')
            print(f"\n🎯 #root element found, innerHTML length: {len(root_html)} characters")
            if len(root_html) < 100:
                print(f"⚠️  #root innerHTML: {root_html}")
            else:
                print(f"✅ #root has content")
        except Exception as e:
            print(f"\n❌ #root element not found: {e}")
        
        # Check for specific elements
        try:
            h1 = driver.find_element(By.TAG_NAME, 'h1')
            print(f"\n✅ Found h1: {h1.text}")
        except Exception as e:
            print(f"\n❌ No h1 found: {e}")
        
        # Take screenshot
        screenshot_path = '/tmp/frontend_screenshot.png'
        driver.save_screenshot(screenshot_path)
        print(f"\n📸 Screenshot saved to {screenshot_path}")
        
        # Get page source
        print(f"\n📄 Page source length: {len(driver.page_source)} characters")

        # Check for script errors in page source
        page_source = driver.page_source
        if 'error' in page_source.lower() or 'failed' in page_source.lower():
            print("\n⚠️  Found 'error' or 'failed' in page source")

        # Print first 2000 chars of page source to see what's loading
        print(f"\n📄 Page source preview:\n{page_source[:2000]}")

        # Check geckodriver logs for browser console output
        print("\n📋 Checking geckodriver logs for browser console...")
        try:
            with open('/tmp/geckodriver.log', 'r') as f:
                log_content = f.read()
                if 'console' in log_content.lower() or 'error' in log_content.lower():
                    print("Found console/error in geckodriver log:")
                    for line in log_content.split('\n'):
                        if 'console' in line.lower() or 'error' in line.lower():
                            print(f"  {line}")
                else:
                    print("  No console errors in geckodriver log")
        except Exception as e:
            print(f"  Could not read geckodriver log: {e}")
        
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
    finally:
        driver.quit()

if __name__ == '__main__':
    test_frontend()

