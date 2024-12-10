
/**
 * Validators Utility for Evire Gaming Framework
 * Provides validation methods for input sanitization and verification.
 */

export const validateEmail = (email: string): boolean => {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
};

export const validateUUID = (uuid: string): boolean => {
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
    return uuidRegex.test(uuid);
};

export const validateNonEmptyString = (str: string): boolean => {
    return typeof str === 'string' && str.trim().length > 0;
};

export const validateNumberInRange = (num: number, min: number, max: number): boolean => {
    return typeof num === 'number' && num >= min && num <= max;
};

export const validateArray = (arr: any[], validator: (item: any) => boolean): boolean => {
    if (!Array.isArray(arr)) return false;
    return arr.every(validator);
};
            