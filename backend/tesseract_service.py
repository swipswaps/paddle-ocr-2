"""
Tesseract OCR Service - Secondary OCR Engine

This service properly uses Tesseract for:
1. Rotation detection (PSM 0 - Orientation and Script Detection)
2. Full OCR with rotation correction (PSM 6 - Uniform block of text)

Previous receipts-ocr implementation only used PSM 0 without extracting text.
This is the CORRECT way to use Tesseract.
"""

import logging
import cv2
import numpy as np
import pytesseract
from PIL import Image
import time
import re

class TesseractService:
    """
    Tesseract OCR service with proper rotation detection and full OCR.
    
    Key improvements over receipts-ocr:
    - Uses PSM 0 for rotation detection
    - Rotates image based on detection
    - Performs full OCR with PSM 6 (uniform block) or PSM 3 (multi-column)
    - Uses OEM 1 (LSTM engine) for better accuracy
    - Returns confidence scores for cascade decisions
    """
    
    def __init__(self):
        self.logger = logging.getLogger(__name__)
        
    def detect_rotation(self, image_path):
        """
        Detect image rotation using Tesseract OSD (Orientation and Script Detection).
        
        PSM 0 = Orientation and script detection only (no text extraction)
        
        Returns:
            int: Rotation angle in degrees (0, 90, 180, 270)
        """
        try:
            # PSM 0: Orientation and script detection only
            osd = pytesseract.image_to_osd(image_path)
            
            # Parse rotation from OSD output
            # Example output: "Rotate: 90\nOrientation confidence: 15.24"
            rotation_match = re.search(r'Rotate: (\d+)', osd)
            rotation = int(rotation_match.group(1)) if rotation_match else 0
            
            # Parse confidence
            conf_match = re.search(r'Orientation confidence: ([\d.]+)', osd)
            confidence = float(conf_match.group(1)) if conf_match else 0.0
            
            self.logger.info(f"[TESSERACT] Detected rotation: {rotation}° (confidence: {confidence:.2f})")
            
            return rotation, confidence
            
        except Exception as e:
            self.logger.warning(f"[TESSERACT] Rotation detection failed: {e}")
            return 0, 0.0
    
    def rotate_image(self, image, angle):
        """
        Rotate image by specified angle.
        
        Args:
            image: numpy array (OpenCV image)
            angle: rotation angle in degrees (0, 90, 180, 270)
            
        Returns:
            numpy array: rotated image
        """
        if angle == 0:
            return image
            
        # Convert angle to OpenCV rotation code
        if angle == 90:
            return cv2.rotate(image, cv2.ROTATE_90_CLOCKWISE)
        elif angle == 180:
            return cv2.rotate(image, cv2.ROTATE_180)
        elif angle == 270:
            return cv2.rotate(image, cv2.ROTATE_90_COUNTERCLOCKWISE)
        else:
            # For arbitrary angles, use affine transformation
            (h, w) = image.shape[:2]
            center = (w // 2, h // 2)
            M = cv2.getRotationMatrix2D(center, -angle, 1.0)
            return cv2.warpAffine(image, M, (w, h), 
                                 flags=cv2.INTER_CUBIC,
                                 borderMode=cv2.BORDER_REPLICATE)
    
    def recognize_text(self, image_path, log_callback=None):
        """
        Perform full OCR with rotation correction.
        
        Process:
        1. Detect rotation with PSM 0
        2. Rotate image if needed
        3. Full OCR with PSM 6 (uniform block) using LSTM engine
        4. Calculate confidence score
        
        Args:
            image_path: path to image file
            log_callback: optional callback for logging
            
        Returns:
            dict: {
                'text': extracted text,
                'confidence': confidence score (0.0 to 1.0),
                'engine': 'Tesseract 5',
                'duration': processing time in seconds,
                'rotation': detected rotation angle,
                'success': True/False
            }
        """
        start_time = time.time()
        
        if log_callback:
            log_callback("[TESSERACT] Starting Tesseract OCR with rotation correction...")
        
        try:
            # Step 1: Detect rotation
            rotation, rotation_conf = self.detect_rotation(image_path)
            
            # Step 2: Load and rotate image if needed
            image = cv2.imread(image_path)
            if image is None:
                raise ValueError(f"Failed to load image: {image_path}")
            
            if rotation != 0:
                if log_callback:
                    log_callback(f"[TESSERACT] Rotating image by {rotation}°...")
                image = self.rotate_image(image, rotation)
            
            # Step 3: Full OCR with optimal settings
            # PSM 6 = Assume a single uniform block of text (best for receipts)
            # OEM 1 = LSTM neural network mode (Tesseract 5)
            custom_config = r'--oem 1 --psm 6'
            
            if log_callback:
                log_callback("[TESSERACT] Performing full OCR (PSM 6, OEM 1)...")
            
            # Convert to PIL Image for pytesseract
            pil_image = Image.fromarray(cv2.cvtColor(image, cv2.COLOR_BGR2RGB))
            
            # Get detailed data for confidence calculation
            data = pytesseract.image_to_data(pil_image, config=custom_config, output_type=pytesseract.Output.DICT)
            
            # Extract text
            text = pytesseract.image_to_string(pil_image, config=custom_config)
            
            # Calculate average confidence from word-level confidences
            confidences = [int(conf) for conf in data['conf'] if conf != '-1']
            avg_confidence = sum(confidences) / len(confidences) if confidences else 0.0
            normalized_confidence = avg_confidence / 100.0  # Convert to 0.0-1.0 range
            
            duration = time.time() - start_time
            
            if log_callback:
                log_callback(f"[TESSERACT] Completed in {duration:.2f}s (confidence: {normalized_confidence:.2f})")
            
            return {
                'text': text.strip(),
                'confidence': normalized_confidence,
                'engine': 'Tesseract 5',
                'duration': duration,
                'rotation': rotation,
                'rotation_confidence': rotation_conf,
                'success': True,
                'word_count': len([w for w in data['text'] if w.strip()])
            }
            
        except Exception as e:
            duration = time.time() - start_time
            self.logger.error(f"[TESSERACT] OCR failed: {e}")
            
            return {
                'text': '',
                'confidence': 0.0,
                'engine': 'Tesseract 5',
                'duration': duration,
                'rotation': 0,
                'success': False,
                'error': str(e)
            }

