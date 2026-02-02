const axios = require("axios");

/**
 * Sends an OTP SMS using 2Factor.in (DLT Compliant)
 * @param {string} phoneNumber - The recipient's phone number
 * @param {string} otp - The OTP to send
 */
const sendOtpSms = async (phoneNumber, otp) => {
    // DLT Configuration
    const apiKey = process.env.TWO_FACTOR_API_KEY;
    const senderId = process.env.DLT_SENDER_ID || "KLBNKA";
    const templateName = process.env.DLT_TEMPLATE_NAME || "KLUB_OTP"; // Must match DLT Dashboard Name exactly

    try {
        if (!apiKey) {
            console.warn("2Factor API Key missing in .env");
            return;
        }

        // Sanitize phone number: Remove '+' (2Factor usually expects 91XXXXXXXXXX or similar without +)
        const cleanPhone = phoneNumber.replace(/\D/g, '');

        // 2Factor TSMS Endpoint (POST form-urlencoded)
        const url = `https://2factor.in/API/V1/${apiKey}/ADDON_SERVICES/SEND/TSMS`;

        // URLSearchParams handles application/x-www-form-urlencoded automatically
        const params = new URLSearchParams();
        params.append("From", senderId);
        params.append("To", cleanPhone);
        params.append("TemplateName", templateName);
        params.append("VAR1", otp); // Replaces {#var#} in the template

        // If Template ID is strictly required by some gateways, we can add it, 
        // but typically TemplateName + SenderID is sufficient for 2Factor mapping.
        // params.append("TemplateId", process.env.DLT_TEMPLATE_ID); 

        console.log(`Sending SMS to: ${cleanPhone}`);
        console.log(`Using Template Name: ${templateName}`);

        const response = await axios.post(url, params, {
            headers: {
                "Content-Type": "application/x-www-form-urlencoded"
            }
        });

        console.log(`OTP SMS sent via 2Factor`);
        console.log(`2Factor Response:`, JSON.stringify(response.data));

    } catch (error) {
        console.error("SMS sending failed:", error.response?.data || error.message);
    }
};

module.exports = sendOtpSms;
