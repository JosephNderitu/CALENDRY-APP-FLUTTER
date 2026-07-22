const {onDocumentCreated, onDocumentUpdated} =
  require("firebase-functions/v2/firestore");
const {setGlobalOptions} = require("firebase-functions/v2");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

// Set global options for all functions
setGlobalOptions({maxInstances: 10});

admin.initializeApp();

// Configure nodemailer transporter
const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: "gikurujoseph53@gmail.com", // Replace with your email
    pass: "gnpk lahq ymli fzgk", // Replace with your app password
  },
});

/**
 * Cloud Function to send email notifications when meeting status changes
 */
exports.sendMeetingNotification = onDocumentUpdated(
    "meetings/{meetingId}",
    async (event) => {
      const beforeData = event.data.before.data();
      const afterData = event.data.after.data();
      const meetingId = event.params.meetingId;

      // Check if status has changed
      if (beforeData.status !== afterData.status) {
        const newStatus = afterData.status;

        // Only send emails for specific status changes
        if (["confirmed", "rejected", "rescheduled"].includes(newStatus)) {
          try {
            await sendNotificationEmail(afterData, newStatus, meetingId);
            console.log(`Email sent successfully for meeting ${meetingId}`);
          } catch (error) {
            console.error(
                `Failed to send email for meeting ${meetingId}:`,
                error,
            );
          }
        }
      }
    },
);

/**
 * NEW: Cloud Function to send verification codes for My Bookings
 */
exports.sendVerificationCode = onDocumentCreated(
    "email_verifications/{emailDoc}",
    async (event) => {
      const verificationData = event.data.data();
      const emailDoc = event.params.emailDoc;

      try {
        await sendVerificationEmail(
            verificationData.email,
            verificationData.code,
        );
        console.log(`Verification code sent to ${verificationData.email}`);

        // Set expiration time (5 minutes from now)
        const expiresAt = admin.firestore.Timestamp.fromDate(
            new Date(Date.now() + 5 * 60 * 1000),
        );

        // Update the document with expiration time
        await admin.firestore()
            .collection("email_verifications")
            .doc(emailDoc)
            .update({expiresAt});
      } catch (error) {
        console.error(
            `Failed to send verification code to ${verificationData.email}:`,
            error,
        );

        // Delete the verification document if email sending fails
        await admin.firestore()
            .collection("email_verifications")
            .doc(emailDoc)
            .delete();
      }
    },
);

/**
 * Sends verification email to user
 * @param {string} email - User email
 * @param {string} code - 6-digit verification code
 * @return {Promise} - Promise that resolves when email is sent
 */
async function sendVerificationEmail(email, code) {
  const mailOptions = {
    from: `"MeetSync Pro" <${
      process.env.GMAIL_EMAIL || "gikurujoseph53@gmail.com"
    }>`,
    to: email,
    subject: "Your MeetSync Pro Verification Code",
    html: generateVerificationEmailTemplate(code),
  };

  return transporter.sendMail(mailOptions);
}

/**
 * Generates verification email template
 * @param {string} code - 6-digit verification code
 * @return {string} - HTML email template
 */
function generateVerificationEmailTemplate(code) {
  return `
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Email Verification - MeetSync Pro</title>
      <style>
        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 
            'Helvetica Neue', Arial, sans-serif;
          line-height: 1.6;
          color: #333;
          max-width: 600px;
          margin: 0 auto;
          padding: 20px;
          background-color: #f8fafc;
        }
        .container {
          background-color: white;
          border-radius: 12px;
          padding: 40px;
          box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
        }
        .header {
          text-align: center;
          margin-bottom: 30px;
        }
        .logo {
          font-size: 28px;
          font-weight: bold;
          color: #1E40AF;
          margin-bottom: 8px;
        }
        .verification-code {
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          color: white;
          font-size: 32px;
          font-weight: bold;
          letter-spacing: 8px;
          padding: 20px;
          border-radius: 12px;
          text-align: center;
          margin: 30px 0;
          font-family: 'Courier New', monospace;
        }
        .instructions {
          background-color: #f0f9ff;
          border-left: 4px solid #0ea5e9;
          padding: 16px;
          margin: 20px 0;
          border-radius: 4px;
        }
        .security-notice {
          background-color: #fef3c7;
          border: 1px solid #f59e0b;
          border-radius: 8px;
          padding: 16px;
          margin: 20px 0;
        }
        .footer {
          text-align: center;
          margin-top: 30px;
          padding-top: 20px;
          border-top: 1px solid #e5e7eb;
          color: #6B7280;
          font-size: 14px;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <div class="logo">📅 MeetSync Pro</div>
          <h1 style="margin: 0; color: #1F2937; font-size: 24px; 
            font-weight: 700;">
            Email Verification
          </h1>
          <p style="color: #6B7280; margin: 8px 0 0 0;">
            Verify your email to view your bookings
          </p>
        </div>

        <p style="font-size: 16px; margin-bottom: 20px;">
          Hello! 👋
        </p>

        <p style="font-size: 16px; margin-bottom: 20px;">
          We received a request to view your meeting bookings. Please use the 
          verification code below to proceed:
        </p>

        <div class="verification-code">
          ${code}
        </div>

        <div class="instructions">
          <h3 style="margin-top: 0; color: #1F2937; font-size: 16px; 
            font-weight: 600;">
            📝 How to use this code:
          </h3>
          <ol style="margin-bottom: 0; padding-left: 20px;">
            <li>Return to the MeetSync Pro app</li>
            <li>Enter this 6-digit code in the verification field</li>
            <li>Click "Verify Code" to access your bookings</li>
          </ol>
        </div>

        <div class="security-notice">
          <h4 style="margin-top: 0; color: #92400e; font-size: 14px; 
            font-weight: 600;">
            🔒 Security Notice
          </h4>
          <ul style="margin-bottom: 0; padding-left: 20px; font-size: 14px; 
            color: #92400e;">
            <li><strong>This code expires in 5 minutes</strong></li>
            <li>Never share this code with anyone</li>
            <li>If you didn't request this code, please ignore this email</li>
          </ul>
        </div>

        <p style="font-size: 16px; margin: 24px 0; text-align: center;">
          Need help? Contact our support team for assistance.
        </p>

        <div class="footer">
          <p>
            This is an automated email from MeetSync Pro.<br>
            Please do not reply to this email.
          </p>
          <p style="font-size: 12px; margin-top: 16px; color: #9CA3AF;">
            © ${new Date().getFullYear()} MeetSync Pro. All rights reserved.
          </p>
        </div>
      </div>
    </body>
    </html>
  `;
}

/**
 * Sends notification email to guest
 * @param {Object} meetingData - Meeting data from Firestore
 * @param {string} status - New meeting status
 * @param {string} meetingId - Meeting document ID
 * @return {Promise} - Promise that resolves when email is sent
 */
async function sendNotificationEmail(meetingData, status, meetingId) {
  const {
    guestName,
    guestEmail,
    hostName,
    date,
    timeSlot,
    purpose,
  } = meetingData;

  const emailTemplate = generateEmailTemplate(
      status,
      guestName,
      hostName,
      date,
      timeSlot,
      purpose,
      meetingId,
  );

  const mailOptions = {
    from: `"${hostName || "Meeting Host"}" <${
      process.env.GMAIL_EMAIL || "gikurujoseph53@gmail.com"
    }>`,
    to: guestEmail,
    subject: emailTemplate.subject,
    html: emailTemplate.html,
  };

  return transporter.sendMail(mailOptions);
}

/**
 * Generates email template based on meeting status
 * @param {string} status - Meeting status
 * @param {string} guestName - Guest name
 * @param {string} hostName - Host name
 * @param {string} date - Meeting date
 * @param {string} timeSlot - Meeting time slot
 * @param {string} purpose - Meeting purpose
 * @param {string} meetingId - Meeting ID
 * @return {Object} - Email template object with subject and html
 */
function generateEmailTemplate(
    status,
    guestName,
    hostName,
    date,
    timeSlot,
    purpose,
    meetingId,
) {
  /**
     * Formats date string to readable format
     * @param {string} dateStr - Date string
     * @return {string} - Formatted date
     */
  const formatDate = (dateStr) => {
    const dateObj = new Date(dateStr);
    return dateObj.toLocaleDateString("en-US", {
      weekday: "long",
      year: "numeric",
      month: "long",
      day: "numeric",
    });
  };

  /**
     * Formats time slot for display
     * @param {string} timeSlotStr - Time slot string
     * @return {string} - Formatted time slot
     */
  const formatTimeSlot = (timeSlotStr) => {
    return timeSlotStr.replace("-", " to ");
  };

  let subject;
  let statusColor;
  let statusText;
  let message;

  switch (status) {
    case "confirmed":
      subject = `Meeting Confirmed - ${formatDate(date)}`;
      statusColor = "#10B981";
      statusText = "CONFIRMED";
      message = "Great news! Your meeting has been confirmed.";
      break;
    case "rejected":
      subject = `Meeting Request Declined - ${formatDate(date)}`;
      statusColor = "#EF4444";
      statusText = "DECLINED";
      message = "We regret to inform you that your meeting request has been " +
        "declined.";
      break;
    case "rescheduled":
      subject = `Meeting Rescheduled - ${formatDate(date)}`;
      statusColor = "#F59E0B";
      statusText = "RESCHEDULED";
      message = "Your meeting has been rescheduled to a new date and time.";
      break;
    default:
      subject = `Meeting Update - ${formatDate(date)}`;
      statusColor = "#6B7280";
      statusText = "UPDATED";
      message = "Your meeting status has been updated.";
  }

  const html = `
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Meeting ${statusText}</title>
      <style>
        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 
            'Helvetica Neue', Arial, sans-serif;
          line-height: 1.6;
          color: #333;
          max-width: 600px;
          margin: 0 auto;
          padding: 20px;
          background-color: #f8fafc;
        }
        .container {
          background-color: white;
          border-radius: 12px;
          padding: 40px;
          box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
        }
        .header {
          text-align: center;
          margin-bottom: 30px;
        }
        .status-badge {
          display: inline-block;
          padding: 8px 16px;
          border-radius: 20px;
          font-size: 12px;
          font-weight: 600;
          letter-spacing: 0.5px;
          color: white;
          margin-bottom: 20px;
        }
        .meeting-details {
          background-color: #f8fafc;
          border-radius: 8px;
          padding: 24px;
          margin: 24px 0;
        }
        .detail-row {
          display: flex;
          margin-bottom: 12px;
          align-items: center;
        }
        .detail-row:last-child {
          margin-bottom: 0;
        }
        .detail-label {
          font-weight: 600;
          color: #374151;
          width: 120px;
          display: inline-block;
        }
        .detail-value {
          color: #6B7280;
          flex: 1;
        }
        .purpose-box {
          background-color: #f0f9ff;
          border-left: 4px solid #0ea5e9;
          padding: 16px;
          margin: 20px 0;
          border-radius: 4px;
        }
        .footer {
          text-align: center;
          margin-top: 30px;
          padding-top: 20px;
          border-top: 1px solid #e5e7eb;
          color: #6B7280;
          font-size: 14px;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <div class="status-badge" style="background-color: ${statusColor};">
            ${statusText}
          </div>
          <h1 style="margin: 0; color: #1F2937; font-size: 24px; 
            font-weight: 700;">
            Meeting ${statusText.toLowerCase().charAt(0).toUpperCase() +
              statusText.toLowerCase().slice(1)}
          </h1>
        </div>

        <p style="font-size: 16px; margin-bottom: 24px;">
          Hello <strong>${guestName}</strong>,
        </p>

        <p style="font-size: 16px; margin-bottom: 24px;">
          ${message}
        </p>

        <div class="meeting-details">
          <h3 style="margin-top: 0; color: #1F2937; font-size: 18px; 
            font-weight: 600;">
            Meeting Details
          </h3>
          
          <div class="detail-row">
            <span class="detail-label">📅 Date:</span>
            <span class="detail-value">${formatDate(date)}</span>
          </div>
          
          <div class="detail-row">
            <span class="detail-label">⏰ Time:</span>
            <span class="detail-value">${formatTimeSlot(timeSlot)}</span>
          </div>
          
          <div class="detail-row">
            <span class="detail-label">👤 Host:</span>
            <span class="detail-value">${hostName || "Meeting Host"}</span>
          </div>
        </div>

        ${purpose ? `
          <div class="purpose-box">
            <h4 style="margin-top: 0; color: #1F2937; font-size: 16px; 
              font-weight: 600;">
              Meeting Purpose
            </h4>
            <p style="margin-bottom: 0; color: #374151;">
              ${purpose}
            </p>
          </div>
        ` : ""}

        ${status === "confirmed" ? `
          <div style="text-align: center;">
            <p style="font-size: 16px; margin-bottom: 16px; color: #10B981; 
              font-weight: 600;">
              📅 Please add this meeting to your calendar
            </p>
          </div>
        ` : ""}

        ${status === "rejected" ? `
          <div style="text-align: center;">
            <p style="font-size: 16px; margin-bottom: 16px; color: #6B7280;">
              You can request a new meeting through the app if needed.
            </p>
          </div>
        ` : ""}

        <div class="footer">
          <p>
            This is an automated notification from MeetSync Pro.<br>
            Please do not reply to this email.
          </p>
          <p style="font-size: 12px; margin-top: 16px;">
            Meeting ID: ${meetingId}
          </p>
        </div>
      </div>
    </body>
    </html>
  `;

  return {subject, html};
}
