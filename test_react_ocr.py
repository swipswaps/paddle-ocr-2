#!/usr/bin/env python3
"""
Test React app OCR functionality with Selenium
Creates a test image and uploads it to verify PaddleOCR works
"""

import time
import os
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.firefox.options import Options
from PIL import Image, ImageDraw, ImageFont

# Create test image with text
def create_test_image():
    """Create a simple test image with text"""
    img = Image.new('RGB', (800, 400), color='white')
    draw = ImageDraw.Draw(img)
    
    # Try to use a font, fallback to default
    try:
        font = ImageFont.truetype("/usr/share/fonts/dejavu/DejaVuSans.ttf", 40)
    except:
        font = ImageFont.load_default()
    
    # Draw test text
    text = "RECEIPT TEST\nTotal: $123.45\nDate: 2025-12-10\nThank you!"
    draw.text((50, 50), text, fill='black', font=font)
    
    test_image_path = '/tmp/test_receipt.png'
    img.save(test_image_path)
    print(f"✅ Created test image: {test_image_path}")
    return test_image_path

# Test React app with Selenium
def test_react_app():
    """Test React app OCR with Selenium"""
    print("🔍 Testing React App OCR...")
    
    # Create test image
    test_image = create_test_image()
    
    # Setup Firefox with headless option
    options = Options()
    # options.add_argument('--headless')  # Comment out to see browser
    
    driver = webdriver.Firefox(options=options)
    
    try:
        # Navigate to React app
        print("📱 Opening React app at http://localhost:3000...")
        driver.get('http://localhost:3000')
        
        # Wait for page to load
        time.sleep(2)
        
        # Find file input
        print("📤 Uploading test image...")
        file_input = driver.find_element(By.CSS_SELECTOR, 'input[type="file"]')
        file_input.send_keys(test_image)

        # Wait for file to be selected
        time.sleep(2)

        # Click "Extract Text" button
        print("🔘 Clicking 'Extract Text' button...")
        extract_button = driver.find_element(By.CSS_SELECTOR, 'button.btn.primary')
        extract_button.click()

        # Wait for processing to start
        print("⏳ Waiting for OCR processing...")
        time.sleep(3)
        
        # Check for logs
        try:
            logs_panel = WebDriverWait(driver, 5).until(
                EC.presence_of_element_located((By.CLASS_NAME, 'logs-panel'))
            )
            print("✅ Logs panel found")
            
            # Get log entries
            log_entries = driver.find_elements(By.CLASS_NAME, 'log-entry')
            print(f"📝 Found {len(log_entries)} log entries:")
            for i, entry in enumerate(log_entries[:10]):  # Show first 10
                print(f"   {i+1}. {entry.text}")
        except Exception as e:
            print(f"⚠️  Could not find logs panel: {e}")
        
        # Wait for OCR to complete (up to 120 seconds for PaddleOCR)
        print("⏳ Waiting for OCR to complete (up to 120s)...")
        try:
            result_element = WebDriverWait(driver, 120).until(
                EC.presence_of_element_located((By.CSS_SELECTOR, '.result-section, .ocr-result, pre'))
            )
            print("✅ OCR completed!")
            
            # Get result text
            result_text = result_element.text
            print(f"\n📄 OCR Result:\n{result_text[:500]}")  # First 500 chars
            
            # Check if expected text is in result
            if "RECEIPT" in result_text or "Total" in result_text or "123" in result_text:
                print("\n✅ SUCCESS: PaddleOCR detected expected text!")
                return True
            else:
                print("\n⚠️  WARNING: Expected text not found in result")
                print(f"Full result: {result_text}")
                return False
                
        except Exception as e:
            print(f"❌ OCR did not complete or result not found: {e}")
            
            # Take screenshot for debugging
            screenshot_path = '/tmp/react_ocr_error.png'
            driver.save_screenshot(screenshot_path)
            print(f"📸 Screenshot saved: {screenshot_path}")
            
            # Print page source for debugging
            print("\n📄 Page source (last 1000 chars):")
            print(driver.page_source[-1000:])
            
            return False
            
    finally:
        # Keep browser open for 5 seconds to see result
        print("\n⏸️  Keeping browser open for 5 seconds...")
        time.sleep(5)
        driver.quit()
        print("🔚 Browser closed")

if __name__ == '__main__':
    success = test_react_app()
    exit(0 if success else 1)

