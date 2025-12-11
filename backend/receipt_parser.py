"""
Receipt Parser - Extract Structured Data from OCR Text

Extracts:
- Merchant name
- Date and time
- Total amount
- Line items (description, quantity, price)
- Tax amount
- Payment method

Uses regex patterns and heuristics informed by receipts-ocr project.
"""

import re
from datetime import datetime
from typing import Dict, List, Optional, Tuple

class ReceiptParser:
    """
    Parse OCR text to extract structured receipt data.
    
    Informed by receipts-ocr patterns but improved with:
    - Better date parsing (multiple formats)
    - More robust price extraction
    - Merchant name detection
    - Tax and subtotal identification
    """
    
    def __init__(self):
        # Common date patterns
        self.date_patterns = [
            r'\b(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})\b',  # MM/DD/YYYY or DD-MM-YYYY
            r'\b(\d{4}[/-]\d{1,2}[/-]\d{1,2})\b',    # YYYY-MM-DD
            r'\b([A-Z][a-z]{2,8}\s+\d{1,2},?\s+\d{4})\b',  # Month DD, YYYY
            r'\b(\d{1,2}\s+[A-Z][a-z]{2,8}\s+\d{4})\b',    # DD Month YYYY
        ]
        
        # Price pattern - matches $X.XX or X.XX
        self.price_pattern = r'\$?\s*(\d+\.\d{2})\b'
        
        # Total keywords (case-insensitive)
        self.total_keywords = [
            'total', 'amount due', 'balance due', 'grand total',
            'amount', 'sum', 'payment'
        ]
        
        # Tax keywords
        self.tax_keywords = ['tax', 'vat', 'gst', 'hst', 'sales tax']
        
        # Subtotal keywords
        self.subtotal_keywords = ['subtotal', 'sub total', 'sub-total']
    
    def parse(self, text: str) -> Dict:
        """
        Parse receipt text and extract structured data.
        
        Args:
            text: OCR extracted text
            
        Returns:
            dict: {
                'merchant': str or None,
                'date': str or None,
                'time': str or None,
                'total': float or None,
                'subtotal': float or None,
                'tax': float or None,
                'items': List[dict],
                'raw_text': str
            }
        """
        lines = text.split('\n')
        
        return {
            'merchant': self.extract_merchant(lines),
            'date': self.extract_date(text),
            'time': self.extract_time(text),
            'total': self.extract_total(lines),
            'subtotal': self.extract_subtotal(lines),
            'tax': self.extract_tax(lines),
            'items': self.extract_items(lines),
            'raw_text': text
        }
    
    def extract_merchant(self, lines: List[str]) -> Optional[str]:
        """
        Extract merchant name (usually first non-empty line).
        
        Heuristic: First line with 3+ characters that's not a number or date.
        """
        for line in lines[:5]:  # Check first 5 lines
            line = line.strip()
            if len(line) >= 3 and not re.match(r'^\d+$', line):
                # Not just numbers
                if not re.search(r'\d{1,2}[/-]\d{1,2}[/-]\d{2,4}', line):
                    # Not a date
                    return line
        return None
    
    def extract_date(self, text: str) -> Optional[str]:
        """Extract date from text using multiple patterns."""
        for pattern in self.date_patterns:
            match = re.search(pattern, text, re.IGNORECASE)
            if match:
                return match.group(1)
        return None
    
    def extract_time(self, text: str) -> Optional[str]:
        """Extract time from text (HH:MM format)."""
        time_pattern = r'\b(\d{1,2}:\d{2}(?::\d{2})?(?:\s*[AP]M)?)\b'
        match = re.search(time_pattern, text, re.IGNORECASE)
        return match.group(1) if match else None
    
    def extract_total(self, lines: List[str]) -> Optional[float]:
        """
        Extract total amount.
        
        Strategy: Find line with 'total' keyword and extract price from it.
        """
        for line in reversed(lines):  # Start from bottom (total usually at end)
            line_lower = line.lower()
            
            # Check if line contains total keyword
            if any(keyword in line_lower for keyword in self.total_keywords):
                # Extract price from this line
                price = self._extract_price_from_line(line)
                if price:
                    return price
        
        return None
    
    def extract_subtotal(self, lines: List[str]) -> Optional[float]:
        """Extract subtotal amount."""
        for line in reversed(lines):
            line_lower = line.lower()
            if any(keyword in line_lower for keyword in self.subtotal_keywords):
                price = self._extract_price_from_line(line)
                if price:
                    return price
        return None
    
    def extract_tax(self, lines: List[str]) -> Optional[float]:
        """Extract tax amount."""
        for line in reversed(lines):
            line_lower = line.lower()
            if any(keyword in line_lower for keyword in self.tax_keywords):
                price = self._extract_price_from_line(line)
                if price:
                    return price
        return None

    def extract_items(self, lines: List[str]) -> List[Dict]:
        """
        Extract line items from receipt.

        Heuristic: Lines with prices that are not total/tax/subtotal.

        Returns:
            List of dicts: [{'description': str, 'price': float}, ...]
        """
        items = []

        # Keywords to skip (these are summary lines, not items)
        skip_keywords = self.total_keywords + self.tax_keywords + self.subtotal_keywords
        skip_keywords.extend(['change', 'cash', 'credit', 'debit', 'card'])

        for line in lines:
            line_lower = line.lower()

            # Skip summary lines
            if any(keyword in line_lower for keyword in skip_keywords):
                continue

            # Extract price from line
            price = self._extract_price_from_line(line)
            if price:
                # Remove price from line to get description
                description = re.sub(self.price_pattern, '', line).strip()

                # Clean up description (remove extra whitespace, tabs)
                description = re.sub(r'\s+', ' ', description)

                if description:  # Only add if we have a description
                    items.append({
                        'description': description,
                        'price': price
                    })

        return items

    def _extract_price_from_line(self, line: str) -> Optional[float]:
        """
        Extract price from a line of text.

        Args:
            line: text line

        Returns:
            float: price or None if not found
        """
        # Find all prices in line
        matches = re.findall(self.price_pattern, line)

        if matches:
            # Return the last price found (usually the actual price, not quantity)
            try:
                return float(matches[-1])
            except ValueError:
                return None

        return None

    def validate_totals(self, parsed_data: Dict) -> Dict:
        """
        Validate that subtotal + tax = total (approximately).

        Args:
            parsed_data: result from parse()

        Returns:
            dict: parsed_data with 'validation' field added
        """
        subtotal = parsed_data.get('subtotal')
        tax = parsed_data.get('tax')
        total = parsed_data.get('total')

        validation = {
            'valid': False,
            'message': ''
        }

        if total is None:
            validation['message'] = 'No total found'
        elif subtotal is not None and tax is not None:
            calculated_total = subtotal + tax
            difference = abs(calculated_total - total)

            if difference < 0.02:  # Allow 2 cent rounding difference
                validation['valid'] = True
                validation['message'] = 'Totals match'
            else:
                validation['valid'] = False
                validation['message'] = f'Totals mismatch: {subtotal} + {tax} = {calculated_total}, but total is {total}'
        else:
            validation['message'] = 'Insufficient data for validation'

        parsed_data['validation'] = validation
        return parsed_data

