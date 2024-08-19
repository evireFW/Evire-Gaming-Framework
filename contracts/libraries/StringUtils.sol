// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title StringUtils
 * @dev A library of utility functions for string manipulation in Solidity.
 * This library provides various helper functions for working with strings
 * in the Evire Gaming Framework.
 */
library StringUtils {
    /**
     * @dev Converts a uint256 to its string representation
     * @param _i The uint256 to convert
     * @return The string representation of the input
     */
    function uintToString(uint256 _i) internal pure returns (string memory) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 length;
        while (j != 0) {
            length++;
            j /= 10;
        }
        bytes memory bstr = new bytes(length);
        uint256 k = length;
        j = _i;
        while (j != 0) {
            bstr[--k] = bytes1(uint8(48 + j % 10));
            j /= 10;
        }
        return string(bstr);
    }

    /**
     * @dev Converts a bytes32 to its string representation
     * @param _bytes32 The bytes32 to convert
     * @return The string representation of the input
     */
    function bytes32ToString(bytes32 _bytes32) internal pure returns (string memory) {
        uint8 i = 0;
        while (i < 32 && _bytes32[i] != 0) {
            i++;
        }
        bytes memory bytesArray = new bytes(i);
        for (uint8 j = 0; j < i; j++) {
            bytesArray[j] = _bytes32[j];
        }
        return string(bytesArray);
    }

    /**
     * @dev Compares two strings for equality
     * @param _a The first string
     * @param _b The second string
     * @return True if the strings are equal, false otherwise
     */
    function equal(string memory _a, string memory _b) internal pure returns (bool) {
        return keccak256(abi.encodePacked(_a)) == keccak256(abi.encodePacked(_b));
    }

    /**
     * @dev Checks if a string contains only alphanumeric characters
     * @param _str The string to check
     * @return True if the string is alphanumeric, false otherwise
     */
    function isAlphanumeric(string memory _str) internal pure returns (bool) {
        bytes memory b = bytes(_str);
        for (uint i = 0; i < b.length; i++) {
            bytes1 char = b[i];
            if (!(char >= 0x30 && char <= 0x39) && // 0-9
                !(char >= 0x41 && char <= 0x5A) && // A-Z
                !(char >= 0x61 && char <= 0x7A)) { // a-z
                return false;
            }
        }
        return true;
    }

    /**
     * @dev Concatenates two strings
     * @param _a The first string
     * @param _b The second string
     * @return The concatenated string
     */
    function concat(string memory _a, string memory _b) internal pure returns (string memory) {
        return string(abi.encodePacked(_a, _b));
    }

    /**
     * @dev Converts a string to lowercase
     * @param _str The string to convert
     * @return The lowercase version of the input string
     */
    function toLowerCase(string memory _str) internal pure returns (string memory) {
        bytes memory bStr = bytes(_str);
        bytes memory bLower = new bytes(bStr.length);
        for (uint i = 0; i < bStr.length; i++) {
            if ((uint8(bStr[i]) >= 65) && (uint8(bStr[i]) <= 90)) {
                bLower[i] = bytes1(uint8(bStr[i]) + 32);
            } else {
                bLower[i] = bStr[i];
            }
        }
        return string(bLower);
    }

    /**
     * @dev Calculates the Levenshtein distance between two strings
     * @param _a The first string
     * @param _b The second string
     * @return The Levenshtein distance
     */
    function levenshteinDistance(string memory _a, string memory _b) internal pure returns (uint256) {
        bytes memory a = bytes(_a);
        bytes memory b = bytes(_b);
        uint256 m = a.length;
        uint256 n = b.length;

        uint256[] memory d = new uint256[](n + 1);
        for (uint256 j = 0; j <= n; j++) {
            d[j] = j;
        }

        for (uint256 i = 1; i <= m; i++) {
            uint256 previousDiagonal = d[0];
            d[0] = i;

            for (uint256 j = 1; j <= n; j++) {
                uint256 oldDiagonal = d[j];
                if (a[i-1] == b[j-1]) {
                    d[j] = previousDiagonal;
                } else {
                    d[j] = min3(d[j] + 1, d[j-1] + 1, previousDiagonal + 1);
                }
                previousDiagonal = oldDiagonal;
            }
        }

        return d[n];
    }

    /**
     * @dev Helper function to find the minimum of three uint256 values
     */
    function min3(uint256 a, uint256 b, uint256 c) private pure returns (uint256) {
        return a < b ? (a < c ? a : c) : (b < c ? b : c);
    }

    function substring(string memory _str, uint256 _startIndex, uint256 _endIndex) internal pure returns (string memory) {
        bytes memory strBytes = bytes(_str);
        require(_startIndex < _endIndex && _endIndex <= strBytes.length, "Invalid indices");
        
        bytes memory result = new bytes(_endIndex - _startIndex);
        for (uint256 i = _startIndex; i < _endIndex; i++) {
            result[i - _startIndex] = strBytes[i];
        }
        return string(result);
    }

    /**
     * @dev Calculates the length of a UTF-8 encoded string
     * @param _str The input string
     * @return The length of the string in characters (not bytes)
     */
    function stringLength(string memory _str) internal pure returns (uint256) {
        uint256 length = 0;
        uint256 i = 0;
        bytes memory stringBytes = bytes(_str);
        
        while (i < stringBytes.length) {
            if (uint8(stringBytes[i]) < 0x80) {
                i += 1;
            } else if (uint8(stringBytes[i]) < 0xE0) {
                i += 2;
            } else if (uint8(stringBytes[i]) < 0xF0) {
                i += 3;
            } else {
                i += 4;
            }
            length++;
        }
        return length;
    }

    /**
     * @dev Reverses a string
     * @param _str The input string
     * @return The reversed string
     */
    function reverse(string memory _str) internal pure returns (string memory) {
        bytes memory strBytes = bytes(_str);
        uint256 length = strBytes.length;
        bytes memory reversed = new bytes(length);
        
        for (uint256 i = 0; i < length; i++) {
            reversed[length - 1 - i] = strBytes[i];
        }
        return string(reversed);
    }

    /**
     * @dev Pads a string with a specified character
     * @param _str The input string
     * @param _length The desired length of the padded string
     * @param _padChar The character to use for padding
     * @param _padLeft If true, pad on the left; otherwise, pad on the right
     * @return The padded string
     */
    function pad(string memory _str, uint256 _length, bytes1 _padChar, bool _padLeft) internal pure returns (string memory) {
        bytes memory strBytes = bytes(_str);
        if (strBytes.length >= _length) return _str;
        
        bytes memory result = new bytes(_length);
        uint256 padLength = _length - strBytes.length;
        
        if (_padLeft) {
            for (uint256 i = 0; i < padLength; i++) {
                result[i] = _padChar;
            }
            for (uint256 i = 0; i < strBytes.length; i++) {
                result[padLength + i] = strBytes[i];
            }
        } else {
            for (uint256 i = 0; i < strBytes.length; i++) {
                result[i] = strBytes[i];
            }
            for (uint256 i = strBytes.length; i < _length; i++) {
                result[i] = _padChar;
            }
        }
        return string(result);
    }

    /**
     * @dev Trims leading and trailing whitespace from a string
     * @param _str The input string
     * @return The trimmed string
     */
    function trim(string memory _str) internal pure returns (string memory) {
        bytes memory strBytes = bytes(_str);
        uint256 start = 0;
        uint256 end = strBytes.length;

        while (start < end && (strBytes[start] == 0x20 || strBytes[start] == 0x09 || strBytes[start] == 0x0A || strBytes[start] == 0x0D)) {
            start++;
        }
        while (end > start && (strBytes[end - 1] == 0x20 || strBytes[end - 1] == 0x09 || strBytes[end - 1] == 0x0A || strBytes[end - 1] == 0x0D)) {
            end--;
        }

        bytes memory result = new bytes(end - start);
        for (uint256 i = start; i < end; i++) {
            result[i - start] = strBytes[i];
        }
        return string(result);
    }

    /**
     * @dev Splits a string into an array of substrings based on a delimiter
     * @param _str The input string
     * @param _delimiter The delimiter to use for splitting
     * @return An array of substrings
     */
    function split(string memory _str, string memory _delimiter) internal pure returns (string[] memory) {
        bytes memory strBytes = bytes(_str);
        bytes memory delimiterBytes = bytes(_delimiter);

        if (strBytes.length == 0) return new string[](0);
        if (delimiterBytes.length == 0) {
            string[] memory result = new string[](1);
            result[0] = _str;
            return result;
        }

        uint256[] memory splitIndices = new uint256[](strBytes.length + 1);
        uint256 numSplits = 0;
        splitIndices[numSplits++] = 0;

        for (uint256 i = 0; i < strBytes.length - delimiterBytes.length + 1; i++) {
            bool isMatch = true;
            for (uint256 j = 0; j < delimiterBytes.length; j++) {
                if (strBytes[i + j] != delimiterBytes[j]) {
                    isMatch = false;
                    break;
                }
            }
            if (isMatch) {
                splitIndices[numSplits++] = i + delimiterBytes.length;
                i += delimiterBytes.length - 1;
            }
        }
        splitIndices[numSplits++] = strBytes.length;

        string[] memory result = new string[](numSplits - 1);
        for (uint256 i = 0; i < numSplits - 1; i++) {
            uint256 length = splitIndices[i + 1] - splitIndices[i];
            bytes memory splitPart = new bytes(length);
            for (uint256 j = 0; j < length; j++) {
                splitPart[j] = strBytes[splitIndices[i] + j];
            }
            result[i] = string(splitPart);
        }
        return result;
    }
}