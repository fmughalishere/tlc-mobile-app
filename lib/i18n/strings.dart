import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app's words, in English and Urdu.
///
/// ── Why the keys look familiar ──
///
/// They are the website's keys, from src/i18n/dictionaries.ts, spelled the
/// same way. "nav.appointments" is "nav.appointments" in both codebases. That
/// costs nothing and buys two things: a string can be copied between web and
/// app without translating it twice, and anyone comparing the two can see at a
/// glance which screens have drifted.
///
/// Missing keys fall back to English and then to the key itself, exactly like
/// the website — so a screen shipped before its Urdu is written reads in
/// English rather than showing `patient.book.title` to a patient.
///
/// What is deliberately NOT here: service names, treatment descriptions,
/// doctor bios. Those are content, they live in Firestore with their own Urdu
/// columns, and the clinic writes them. A medical catalogue translated by a
/// developer guessing is worse than one left in English.
class Strings {
  const Strings._();

  static const en = <String, String>{
    'app.name': 'TLC Med Clinics',
    'app.tagline': 'Mental health and skin care, under one roof.',

    'common.retry': 'Try again',
    'common.cancel': 'Cancel',
    'common.save': 'Save',
    'common.close': 'Close',
    'common.back': 'Back',
    'common.next': 'Next',
    'common.confirm': 'Confirm',
    'common.done': 'Done',
    'common.loading': 'Loading…',
    'common.offline': 'You appear to be offline.',
    'common.somethingWrong': 'Something went wrong.',
    'common.callClinic': 'Call the clinic',
    'common.whatsapp': 'WhatsApp',
    'common.optional': 'optional',
    'common.seeAll': 'See all',
    'common.nothingHere': 'Nothing here yet',
    'common.signInRequired': 'Sign in to see this.',

    'nav.home': 'Home',
    'nav.appointments': 'Bookings',
    'nav.services': 'Services',
    'nav.alerts': 'Alerts',
    'nav.profile': 'Profile',

    'auth.signIn': 'Sign in',
    'auth.signOut': 'Sign out',
    'auth.createAccount': 'Create account',
    'auth.haveAccount': 'Already have an account?',
    'auth.noAccount': "Don't have an account?",
    'auth.name': 'Full name',
    'auth.phone': 'Phone number',
    'auth.email': 'Email',
    'auth.password': 'Password',
    'auth.forgot': 'Forgot password?',
    'auth.resetSent': 'Password reset email sent.',
    'auth.withEmail': 'Email',
    'auth.withPhone': 'Phone',
    'auth.sendCode': 'Send code',
    'auth.invalidPhone': "That doesn't look like a valid phone number.",
    'auth.invalidCode': "That code isn't right. Please check and try again.",
    'auth.codeExpired': 'That code has expired — request a new one.',
    'auth.tooManyRequests': 'Too many attempts. Please wait a few minutes.',
    'auth.resendTooSoon': 'Please wait a moment before asking for another code.',
    'auth.smsFailed': "We couldn't send the code. Please try again, or use email.",
    'auth.smsNotConfigured':
        "Phone sign-in isn't set up yet. Please use email for now.",
    'net.timeout':
        "The clinic's server took too long to answer. Check your connection and try again.",
    'net.offline': 'No connection. Check your internet and try again.',
    'net.dropped': 'The connection dropped. Please try again.',
    'net.unreadable': 'The server answered with something the app could not read.',
    'net.signInAgain': 'Please sign in again.',
    'net.forbidden': 'You do not have permission to do that.',
    'net.notFound': 'That is not there any more.',
    'net.conflict': 'Somebody else got there first. Please try again.',
    'net.serverProblem': "The clinic's server had a problem. Please try again.",
    'net.generic': 'Something went wrong. Please try again.',
    'net.cannotOpen': 'Nothing on this phone can open that.',
    'net.notSaved': "That change wasn't saved. Please try again.",
    'auth.googleNoAccount': 'Google signed in, but no account came back.',
    'sess.inPerson': 'In-person visit',
    'sess.cancelled': 'Cancelled',
    'sess.awaitingConfirmation': 'Awaiting confirmation',
    'sess.awaitingPayment': 'Awaiting patient payment',
    'sess.ended': 'Session ended',
    'sess.live': 'Live now',
    'sess.scheduled': 'Scheduled',
    'sess.readyToJoin': 'Ready to join',
    'sess.startingSoon': 'Starting soon',
    'sess.startsInMin': 'Starts in {n} min',
    'sess.startsInHours': 'Starts in {n}h',
    'auth.invalidEmail': 'That email address does not look right.',
    'auth.wrongCredentials': 'Email or password is incorrect.',
    'auth.signInFailed': 'Could not sign you in.',
    'auth.emailInUse': 'That email already has an account. Try signing in instead.',
    'auth.registerFailed': 'Could not create the account.',
    'auth.noUserReturned': 'Account created but no user returned.',
    'auth.googleNotSetUp':
        "Google sign-in is not set up for this build yet — the app's SHA-1 fingerprint needs adding in the Firebase console.",
    'rate.care': 'Quality of care',
    'rate.listening': 'Listening to concerns',
    'rate.courtesy': 'Courtesy of staff',
    'rate.efficiency': 'Waiting time',
    'rate.recommend': 'Would recommend',
    'auth.enterCode': 'Enter the 6-digit code',
    'auth.codeSentTo': 'We sent a code to',
    'auth.verify': 'Verify',
    'auth.resend': 'Send it again',
    'auth.blocked': 'This account has been suspended. Please call the clinic.',
    'auth.welcome': 'Welcome back',
    'auth.welcomeSub': 'Sign in to book and manage your appointments.',
    'auth.createSub': 'A few details and you can book straight away.',
    'auth.browse': 'Just looking around',
    'auth.needName': 'Please enter your name.',
    'auth.needEmail': 'Please enter your email.',
    'auth.needPassword': 'Password must be at least 6 characters.',
    'auth.needPhone': "That phone number doesn't look right.",
    'auth.phoneHelp': 'We will text you a 6-digit code.',
    'auth.or': 'or',
    'auth.continueWithGoogle': 'Continue with Google',
    'auth.googleFailed': "Couldn't sign in with Google. Please try again.",
    'auth.imPatient': "I'm a patient",
    'auth.imDoctor': "I'm a doctor",
    'auth.patientIntro':
        'Book appointments, see your prescriptions, and keep everything in one place.',
    'auth.doctorIntro':
        'Apply to join the clinic. An admin reviews every request, so your account '
            'stays inactive until it is approved.',
    'auth.specializationHint': 'e.g. Psychiatry',
    'auth.doctorPending':
        'Account created. Your request to join as a doctor is waiting for admin '
            'approval — we will let you know as soon as it is reviewed.',
    'auth.confirmPassword': 'Confirm password',
    'auth.passwordsDontMatch': "The two passwords don't match.",
    'auth.doctorNeedsEmail':
        'Doctor accounts are created with an email address, so the clinic has a '
            'way to reach you about your application.',
    'auth.doctorLoginIntro':
        'Sign in to your clinic account — your schedule, your patients, and '
            'their prescriptions.',
    'auth.rolePatientActually':
        'This account is registered as a patient, so that is where we are '
            'taking you.',
    'auth.roleDoctorActually':
        'This account is registered as a doctor, so that is where we are '
            'taking you.',
    'auth.roleAdminActually':
        'This is an admin account, so that is where we are taking you.',
    'auth.verifyTitle': 'Verify your email',
    'auth.verifyHeading': 'One more step',
    'auth.verifySentTo': 'We have sent a verification link to',
    'auth.verifyStep1': 'Open that email and tap the link inside it.',
    'auth.verifyStep2': 'Come back here — the app will let you in by itself.',
    'auth.verifySpam': "Can't see it? Look in your spam or junk folder.",
    'auth.verifyDone': "I've done it — check now",
    'auth.verifyResend': 'Send the email again',
    'auth.verifyResent': 'Sent. It can take a minute to arrive.',
    'auth.verifyNotYet':
        'Not verified yet. Open the link in the email, then try again.',
    'auth.verifyThanks': 'Email verified. Welcome.',
    'auth.verifyTooMany':
        'Too many emails sent just now. Please wait a few minutes.',
    'auth.verifyFailed': "Couldn't send the email. Please try again.",
    'auth.verifyWrongEmail': 'Wrong email address, or not your account?',

    'splash.checking': 'Getting things ready…',

    'home.greeting': 'Hello',
    'home.guest': 'there',
    'home.book': 'Book an appointment',
    'home.bookSub': 'Pick a service and a time',
    'home.upcoming': 'Your next appointment',
    'home.noUpcoming': 'No upcoming appointments',
    'home.noUpcomingSub': 'When you book one, it will show here.',
    'home.ourServices': 'Our services',
    'home.ourDoctors': 'Our doctors',
    'home.callSub': 'Talk to the clinic now',

    'services.title': 'Services',
    'services.empty': 'The clinic has not published any services yet.',
    'services.whatsIncluded': "What's included",
    'services.treatments': 'Treatments',
    'services.duration': 'Duration',
    'services.minutes': 'minutes',
    'services.price': 'Price',
    'services.advance': 'Pay now to hold',
    'services.bookThis': 'Book this',

    'doctors.title': 'Doctors',
    'doctors.empty': 'No doctors are listed yet.',
    'doctors.online': 'Online now',
    'doctors.offline': 'Offline',

    'book.title': 'Book an appointment',
    'book.step1': 'Choose a service',
    'book.step2': 'How would you like to be seen?',
    'book.step3': 'Pick a time',
    'book.step4': 'Confirm',
    'book.online': 'Online',
    'book.onlineSub': 'Video or audio call',
    'book.inClinic': 'At the clinic',
    'book.inClinicSub': 'Visit us in Lahore',
    'book.noSlots': 'No open times for this right now.',

    // Shown only when the OTHER mode has times — see _NoTimesHere in
    // book_screen.dart. {n} is filled in at render time.
    'book.tryInClinic': 'There are {n} times open at the clinic for this service.',
    'book.tryOnline': 'There are {n} online times open for this service.',
    'book.switchInClinic': 'See clinic visit times',
    'book.switchOnline': 'See online times',
    'book.noSlotsSub':
        'You can ask the clinic to arrange one — they will call you to fix a time.',
    'book.requestInstead': 'Ask the clinic to arrange a time',
    'book.preferredWhen': 'When would suit you?',
    'book.preferredWhenHint': 'e.g. weekday mornings, after 6pm',
    'book.notes': 'Anything the doctor should know?',
    'book.yourName': 'Your name',
    'book.yourPhone': 'Your phone number',
    'book.summary': 'Booking summary',
    'book.service': 'Service',
    'book.doctor': 'Doctor',
    'book.when': 'When',
    'book.howSeen': 'How',
    'book.payLater': 'The clinic will call you to confirm and take payment.',
    'book.submit': 'Request this appointment',
    'book.booked': 'Booked. The clinic will call you shortly.',
    'book.requested': 'Request sent. The clinic will call you shortly.',
    'book.howPay': 'How would you like to pay?',
    'book.payNow': 'Pay now',
    'book.payNowSub': 'Pay the advance now and your time is confirmed straight away.',
    'book.payAtClinic': 'Pay when the clinic calls',
    'book.payAtClinicSub':
        'We hold your time and ring you to confirm. Nothing is charged now.',
    'book.payable': 'To pay now',
    'book.paid': 'Paid. Your appointment is confirmed.',
    'book.payFailed': 'That payment did not go through. Your time has been released.',
    'book.payCancelled': 'Payment cancelled. Nothing has been charged.',
    'book.payAttention':
        'We could not confirm that payment yet. Your time is still held — please call the clinic before paying again.',
    'pay.secureNote': 'This page belongs to the payment provider. Your card never reaches the clinic or this app.',
    'pay.pageFailed': "That page couldn't load. Check your connection and try again.",
    'pay.leaveTitle': 'Leave without paying?',
    'pay.leaveBody':
        'If you have already entered your card, wait a moment for it to finish. '
            'Leaving now releases the time you picked.',
    'pay.keepPaying': 'Stay here',
    'pay.openingBrowser':
        'Opening the payment page in your browser…',
    'pay.openingGateway': 'Taking you to the payment page…',
    'appt.joinNotReady':
        'The session room is not open yet. Please try again in a moment.',
    'pay.leave': 'Leave',
    'pay.openInBrowser': 'Open in your browser',
    'pay.browserUnavailable':
        'This payment method can only be completed here in the app.',
    'pay.inBrowser':
        'The payment page is open in your browser. Finish paying there, then come back — pull down to refresh and your appointment will appear once the payment clears.',
    'pay.chooseMethod': 'How would you like to pay?',
    'pay.confirmAndPay': 'Confirm and pay',
    'pay.dueNow': 'Due now',
    'pay.noMethods':
        'Online payment isn\u2019t open yet. Please call the clinic to confirm this time.',
    'pay.holdNote':
        'This time is held for you until you pay. Payment is completed on the provider\u2019s own secure page.',

    'appt.title': 'Appointments',

    // The date filter above every appointments list — patient, doctor, clinic.
    'range.from': 'From',
    'range.to': 'To',
    'range.today': 'Today',
    'range.week': 'Last 7 days',
    'range.month': 'Last 30 days',
    'range.upcoming': 'Next 30 days',
    'range.clear': 'Clear dates',
    'range.matched': 'in these dates',
    'range.empty': 'No appointments in these dates.',
    'appt.upcoming': 'Upcoming',
    'appt.past': 'Past',
    'appt.empty': 'No appointments yet.',
    'appt.emptySub': 'Book one and it will appear here.',
    'appt.status.pending': 'Waiting for the clinic to call',
    'appt.status.awaiting-payment': 'Waiting for your payment',
    'appt.statusStaff.awaiting-payment': 'Awaiting payment',
    'appt.status.confirmed': 'Confirmed',
    'appt.status.completed': 'Completed',
    'appt.status.cancelled': 'Cancelled',
    'appt.needsDoctor': 'The clinic is assigning a doctor',
    'appt.notScheduled': 'Time not fixed yet',
    'appt.details': 'Appointment',
    'appt.prescription': 'Prescription',
    'appt.noPrescription': 'No prescription has been added yet.',
    'appt.joinCall': 'Join the call',
    'appt.cancel': 'Cancel this appointment',
    'appt.cancelConfirm': 'Cancel this appointment?',
    'appt.cancelConfirmSub': 'The time will be released for someone else.',
    'appt.cancelled': 'Appointment cancelled.',
    'appt.keepIt': 'Keep it',
    'appt.amount': 'Amount',
    'appt.paid': 'Paid',
    'appt.unpaid': 'Not paid',
    'appt.bookedOn': 'Booked on',
    'appt.rate': 'Rate this visit',
    'appt.yourRating': 'Your rating',

    'alerts.title': 'Alerts',
    'alerts.empty': 'No alerts.',
    'alerts.emptySub': 'Reminders and confirmations will show up here.',
    'alerts.markAllRead': 'Mark all as read',

    'profile.title': 'Profile',
    'profile.editName': 'Name',
    'profile.unnamedPatient': 'Patient',
    'profile.language': 'Language',
    'profile.contact': 'Contact the clinic',
    'profile.saved': 'Saved.',
    'profile.diagnostics': 'Connection check',
    'profile.signOutConfirm': 'Sign out of this device?',

    'staff.title': 'Staff',
    'staff.doctorSub': "Today's appointments assigned to you.",
    'staff.adminSub': 'The admin panel is on the website for now.',
    'staff.openWebsite': 'Open the website',


    'common.edit': 'Edit',

    'home.subtitle': 'Book a visit, or pick up where you left off.',
    'home.needHelp': 'Need a hand?',
    'home.ourDoctorsSub': 'See who is available today',

    'services.search': 'Search services',
    'services.noMatch': 'Nothing matches that',
    'services.noMatchSub': 'Try a shorter word, or the treatment name.',

    'appt.emptyUpcoming': 'Nothing booked yet',
    'appt.emptyPast': 'No past visits',
    'appt.emptyPastSub': 'Visits you have completed will be listed here.',

    'profile.account': 'Your details',
    'profile.preferences': 'Preferences',
    'profile.doctorDetails': 'Doctor profile',
    'profile.developer': 'Developer',
    'profile.addName': 'Add your name',
    'profile.tapToEdit': 'Tap to edit',
    'profile.notSet': 'Not added yet',
    'profile.emailLooksWrong': "That email doesn't look right.",
    'profile.contactNote':
        'The clinic uses these to reach you about your appointments. Changing them here does not change how you sign in.',
    'profile.notificationSound': 'Notification sound',
    'profile.notificationSoundSub': 'Chime when the clinic sends an update',
    'profile.messageSound': 'Message sound',
    'profile.messageSoundSub': 'Tone for chat messages',
    'profile.specialization': 'Specialisation',
    'profile.bio': 'About you',
    'profile.showOnline': 'Show me as online',
    'profile.showOnlineSub': 'Patients can see when you are available',
    'profile.emailUs': 'Email us',
    'profile.signOutPartial':
        'Signed out on this phone, but the server could not be reached.',

    'doc.nav.overview': 'Overview',
    'doc.nav.appointments': 'Visits',
    'doc.nav.availability': 'My times',
    'doc.nav.patients': 'Patients',

    'doc.overview.title': 'Doctor',
    'doc.overview.hello': 'Hello',
    'doc.overview.subtitle': "Your day, and what needs you.",
    'doc.overview.today': "Today's schedule",
    'doc.overview.nothingToday': 'Nothing on the schedule for today.',
    'doc.presence.on': 'Patients can see you are online',
    'doc.presence.hidden': 'You are hidden from patients',
    'doc.presence.change': 'Change',
    'doc.stat.today': "Today's sessions",
    'doc.stat.upcoming': 'Upcoming confirmed',
    'doc.stat.patients': 'My patients',
    'doc.stat.completed': 'Completed',

    'doc.appointments.title': 'Appointments',
    'doc.appointments.search': 'Search patient, service or date',
    'doc.appointments.empty': 'No appointments here.',
    'doc.filter.all': 'All',
    'doc.markAs': 'Mark as',
    'doc.updated': 'Updated.',
    'doc.joinAsHost': 'Join as host',
    'doc.openChat': 'Open secure chat',
    'doc.startEarly': 'Start early',
    'doc.connecting': 'Connecting…',
    'doc.endSession': 'End session',
    'doc.endSessionSub':
        'This ends the call for everyone and marks the visit completed.',
    'doc.sessionEnded': 'Session ended.',
    'doc.addPrescription': 'Prescription',
    'doc.editPrescription': 'Prescription',
    'doc.followUp': 'Follow-up',

    'doc.rx.text': 'Prescription',
    'doc.rx.hint': 'Medicines, dosage, instructions…',
    'doc.rx.images': 'Photos',
    'doc.rx.add': 'Add',
    'doc.rx.addImage': 'Paste the image link',
    'doc.rx.noImages':
        'None attached. You can paste the link of a photo already uploaded on the website.',
    'doc.rx.badUrl': 'That does not look like a link.',
    'doc.rx.maxImages': 'Six photos is the limit.',
    'doc.rx.needSomething': 'Write the prescription, or attach a photo of it.',
    'doc.rx.save': 'Save prescription',
    'doc.rx.saved': 'Prescription saved.',
    'doc.rx.visibleNote': 'The patient can see this as soon as you save it.',

    'doc.fu.after': 'Following',
    'doc.fu.pickTime': 'Pick a time from your own calendar',
    'doc.fu.noSlots': 'You have no open times.',
    'doc.fu.noSlotsSub': 'Open some under My times, then come back here.',
    'doc.fu.note': 'Note for the patient',
    'doc.fu.noteHint': 'What this follow-up is for',
    'doc.fu.pickFirst': 'Pick a time first',
    'doc.fu.book': 'Book',
    'doc.fu.booked': 'Follow-up booked. The patient has been asked to pay.',
    'doc.fu.paymentNote':
        'The time is held for the patient until they pay. If the hold lapses, the slot is released automatically.',

    'doc.av.title': 'My availability',
    'doc.av.subtitle': 'Open the times you can see patients, and mark the days you are away.',
    'doc.av.addTimes': 'Open times',
    'doc.av.day': 'Day',
    'doc.av.from': 'From',
    'doc.av.to': 'To',
    'doc.av.each': 'Length of each appointment',
    'doc.av.service': 'For which service?',
    'doc.av.anyService': 'Any service',
    'doc.av.willOpen': 'times will open:',
    'doc.av.noneFit': 'No appointment fits between those two times.',
    'doc.av.openThem': 'Open these times',
    'doc.av.opened': 'times opened.',
    'doc.av.myTimes': 'My times',
    'doc.av.noTimes': 'No open times yet',
    'doc.av.noTimesSub': 'Add some so patients can book with you.',
    'doc.av.booked': 'Booked',
    'doc.av.remove': 'Remove',
    'doc.av.removeTime': 'Remove this time?',
    'doc.av.removeTimeSub': 'Patients will no longer see it.',
    'doc.av.daysAway': 'Days away',
    'doc.av.daysAwaySub':
        'Marking leave removes your open times in those days and stops new ones being added.',
    'doc.av.markAway': 'Mark away',
    'doc.av.dates': 'Dates',
    'doc.av.reason': 'Reason',
    'doc.av.reasonHint': 'Conference',
    'doc.av.noLeave': 'No leave booked.',
    'doc.av.leaveSaved': 'Leave saved.',
    'doc.av.timesRemoved': 'open times removed.',
    'doc.av.leaveSavedBut':
        'Leave saved, but the clinic must reschedule these already-booked appointments:',
    'doc.av.removeLeave': 'Remove this leave?',
    'doc.av.removeLeaveSub':
        'Those days become open again. The times that were cleared are not restored — you will need to add them back.',

    'doc.patients.title': 'Patients',
    'doc.patients.one': 'Patient',
    'doc.patients.search': 'Search by name or number',
    'doc.patients.empty': 'No patients yet.',
    'doc.patients.sessions': 'visits',
    'doc.patients.lastSeen': 'last seen',
    'doc.patients.next': 'Next session',
    'doc.patients.totalWithYou': 'Visits with you',
    'doc.patients.history': 'Appointment history',
    'doc.patients.noRecord': 'No record found',
    'doc.patients.noRecordSub': 'This patient may not be assigned to you any more.',

    'adm.nav.doctors': 'Doctors',
    'adm.nav.catalogue': 'Catalogue',

    'adm.overview.title': 'Clinic',
    'adm.overview.clinic': 'The clinic',
    'adm.overview.recent': 'Recently',
    'adm.overview.days': 'days',
    'adm.overview.callBacks': 'bookings need a call',
    'adm.overview.callBacksSub': 'Patients waiting for the clinic to confirm',
    'adm.overview.byQuestion': 'What patients rate lowest',
    'adm.overview.byQuestionSub':
        'The overall average cannot say which part of a visit is the problem. These five can.',
    'adm.overview.byDoctor': 'By doctor',
    'adm.overview.noRatings': 'no ratings yet',
    'adm.stat.patients': 'Patients',
    'adm.stat.appointments': 'Appointments',
    'adm.stat.services': 'Services',
    'adm.stat.blogs': 'Posts',
    'adm.stat.revenue': 'Paid',
    'adm.stat.refunded': 'Refunded',
    'adm.stat.completed': 'Completed visits',
    'adm.stat.completedLower': 'completed',
    'adm.stat.rating': 'Average rating',

    'adm.appt.title': 'All bookings',
    'adm.appt.search': 'Patient, doctor, service or date',
    'adm.appt.noDoctor': 'No doctor assigned',
    'adm.appt.needsDoctor': 'Needs a doctor',
    'adm.appt.needsDoctorSub':
        'No doctor covering this service had an open time. Assign one, then set a time.',
    'adm.appt.assign': 'Assign a doctor',
    'adm.appt.assigned': 'Assigned to',
    'adm.appt.reschedule': 'Reschedule',
    'adm.appt.pickNewTime': 'Pick a new time',
    'adm.appt.rescheduled': 'Moved. The patient and doctor have been told.',
    'adm.appt.noSlotsSub': 'This doctor has no open times. Ask them to open some.',
    'adm.appt.refund': 'Issue refund',
    'adm.appt.refundTitle': 'Issue a refund?',
    'adm.appt.refundSub':
        'This sends real money back through the payment provider. It cannot be undone from here.',
    'adm.appt.refunded': 'Refund sent.',
    'adm.appt.awaitingRefund': 'Cancelled and paid — awaiting refund',

    'adm.doc.title': 'Doctors',
    'adm.doc.all': 'All doctors',
    'adm.doc.pending': 'Waiting for approval',
    'adm.doc.pendingSub':
        'They cannot sign in or be booked until you decide. Nobody tells them you are looking.',
    'adm.doc.approve': 'Approve',
    'adm.doc.approved': 'Approved. They can sign in now.',
    'adm.doc.reject': 'Reject',
    'adm.doc.rejected': 'Rejected.',
    'adm.doc.rejectTitle': 'Reject this request?',
    'adm.doc.rejectSub': 'Their sign-in is disabled. You can approve them later.',
    'adm.doc.rejectedTag': 'Rejected',
    'adm.doc.activeTag': 'Active',
    'adm.doc.suspendedTag': 'Suspended',
    'adm.doc.suspend': 'Suspend',
    'adm.doc.suspendTitle': 'Suspend this doctor?',
    'adm.doc.suspendSub':
        'They are signed out and hidden from patients straight away. Their appointments stay.',
    'adm.doc.reinstate': 'Reinstate',
    'adm.doc.add': 'Add a doctor',
    'adm.doc.addSub':
        'Creates the account outright and approves it. Hand the password over, and ask them to change it.',
    'adm.doc.create': 'Create the account',
    'adm.doc.created': 'Doctor added.',
    'adm.doc.tempPassword': 'Starting password',
    'adm.doc.tempPasswordHelp': 'They sign in with this the first time.',
    'adm.doc.needPassword': 'The password must be at least 8 characters.',

    'adm.cat.title': 'Catalogue',
    'adm.cat.services': 'Services',
    'adm.cat.coupons': 'Codes',
    'adm.cat.blog': 'Blog',
    'adm.cat.newService': 'New service',
    'adm.cat.newCoupon': 'New code',
    'adm.cat.newPost': 'New post',
    'adm.cat.urdu': 'Urdu',
    'adm.cat.delete': 'Delete',
    'adm.cat.open': 'Open',
    'adm.cat.deleteService': 'Delete this service?',
    'adm.cat.deleteServiceSub':
        'It disappears from the website and the app. Appointments already booked for it are untouched.',
    'adm.cat.noCoupons': 'No discount codes',
    'adm.cat.noCouponsSub': 'Create one and patients can enter it at checkout.',
    'adm.cat.liveTag': 'Live',
    'adm.cat.switchedOff': 'Switched off',
    'adm.cat.expiredTag': 'Expired',
    'adm.cat.usedUp': 'Used up',
    'adm.cat.switchOff': 'Switch off',
    'adm.cat.switchOn': 'Switch on',
    'adm.cat.off': 'off',
    'adm.cat.used': 'used',
    'adm.cat.until': 'until',
    'adm.cat.deleteCoupon': 'Delete this code?',
    'adm.cat.deleteCouponSub': 'Anyone holding it will find it no longer works.',
    'adm.cat.code': 'Code',
    'adm.cat.codeHelp': 'Patients type this at checkout. Saved in capitals.',
    'adm.cat.percent': 'Percent',
    'adm.cat.flat': 'Fixed',
    'adm.cat.percentOff': 'Percent off',
    'adm.cat.rupeesOff': 'Rupees off',
    'adm.cat.maxUses': 'How many times it can be used',
    'adm.cat.noExpiry': 'No expiry date',
    'adm.cat.createCoupon': 'Create the code',
    'adm.cat.needCode': 'Give the code a name.',
    'adm.cat.needValue': 'Enter how much it takes off.',
    'adm.cat.percentTooBig': 'A percentage cannot be more than 100.',
    'adm.cat.noPosts': 'No posts yet',
    'adm.cat.published': 'Published',
    'adm.cat.draft': 'Draft',
    'adm.cat.publish': 'Publish',
    'adm.cat.unpublish': 'Unpublish',
    'adm.cat.deletePost': 'Delete this post?',
    'adm.cat.deletePostSub': 'It is removed from the website.',
    'adm.cat.postTitle': 'Title',
    'adm.cat.postExcerpt': 'Short summary',
    'adm.cat.postContent': 'The post',
    'adm.cat.publishNow': 'Publish it now',
    'adm.cat.publishNowSub': 'Off means it is saved as a draft.',
    'adm.cat.needTitleContent': 'A post needs a title and something in it.',
    'adm.cat.longFormNote':
        'Long posts and the Urdu translation screen are easier on the website, on a keyboard.',

    'adm.svc.edit': 'Edit service',
    'adm.svc.name': 'Name',
    'adm.svc.short': 'One-line summary',
    'adm.svc.intro': 'Full description',
    'adm.svc.category': 'Category',
    'adm.svc.categoryHelp': 'Services are grouped by this on the website and in the app.',
    'adm.svc.onePerLine': 'One per line.',
    'adm.svc.moneyTime': 'Price and length',
    'adm.svc.priceHelp': 'Leave empty to show no price.',
    'adm.svc.advanceHelp':
        'Taken online to hold the appointment. Leave empty to charge the full price; 0 means nothing is taken.',
    'adm.svc.image': 'Image link',
    'adm.svc.imageHelp': 'A Cloudinary URL, uploaded from the website.',
    'adm.svc.needNameCategory': 'A service needs a name and a category.',
    'adm.svc.saved': 'Saved.',

    'auth.continueWithApple': 'Sign in with Apple',
    'auth.appleFailed': "Couldn't sign in with Apple. Please try again.",
    'auth.agreePrefix': 'By creating an account you agree to the ',
    'auth.agreeAnd': ' and ',
    'auth.agreeSuffix': '.',

    'legal.title': 'Legal',
    'legal.privacy': 'Privacy Policy',
    'legal.terms': 'Terms of Service',
    'legal.refund': 'Refund Policy',

    'account.delete': 'Delete account',
    'account.staffDelete':
        'Doctor and admin accounts are closed by the clinic. To close yours, please contact the clinic.',
    'account.deleteTitle': 'Delete your account?',
    'account.deleteIntro': 'This is what happens:',
    'account.deleteUpcoming':
        'Your upcoming appointments are cancelled and their times given back to the clinic. Anything already paid is not refunded automatically — if you are owed a refund, contact the clinic first.',
    'account.deleteLogin':
        'Your sign-in is removed, and your name, email, phone and photo are taken off your profile.',
    'account.deleteNotifications': 'This phone stops receiving notifications from the clinic.',
    'account.deleteRecords':
        'Your past visits, prescriptions and payments are kept by the clinic, as it must keep medical records, but without your name or phone number on them.',
    'account.deleteFinal': 'This cannot be undone.',
    'account.deleteTypePrompt': 'To confirm, type {word} below.',
    'account.deleteWord': 'DELETE',
    'account.deleteForever': 'Delete for good',
    'account.deleting': 'Deleting your account…',
    'account.deleteFailed': 'Your account was not deleted, and you are still signed in.',
    'account.deleted': 'Your account has been deleted.',


    // ── Booking parity, contact and information (website parity) ──
    'book.newPatient': 'New patient',
    'book.newPatientHint':
        'First visit? Choose a service below. If you have a coupon, you can add it on the last step.',
    'book.followUp': 'Follow-up',
    'book.followUpHint':
        'Already a patient? Book a regular follow-up, or a longer 30 or 60 minute session.',
    'book.noServicesType': 'No services of this kind are open for booking right now.',
    'book.howToMeet': 'How would you like to meet?',
    'mode.video': 'Video call',
    'mode.audio': 'Audio call',
    'mode.chat': 'Chat',
    'book.coupon': 'Have a coupon?',
    'book.couponPlaceholder': 'Coupon code (optional)',
    'book.apply': 'Apply',
    'book.couponApplied': 'Coupon applied.',
    'book.couponAppliedCode': '{code} applied',
    'book.couponSaving': '{discount} off. You pay {total} now.',
    'book.couponServerNote': 'The clinic confirms the final price when you book.',
    'book.couponRemove': 'Remove',
    'book.couponInvalid': 'This coupon isn\'t valid right now.',
    'book.couponNotFound': 'That code was not recognised.',
    'book.couponInactive': 'That code is no longer active.',
    'book.couponExpired': 'That code has expired.',
    'book.couponUsedUp': 'That code has already been used the maximum number of times.',
    'book.couponNotForYou': 'That code is not valid for this account.',
    'book.discount': 'Discount',
    'book.priceChanged':
        'The clinic\'s price for this booking is {amount}. That is the amount you will pay.',
    'contact.title': 'Contact the clinic',
    'contact.homeSub': 'Send us a question by message',
    'contact.form.lede': 'Ask us anything — fees, timings, whether a treatment is right for you.',
    'contact.form.name': 'Name',
    'contact.label.phone': 'Phone',
    'contact.form.message': 'Message',
    'contact.form.messagePlaceholder': 'Tell us what you would like to know.',
    'contact.form.privacy':
        'Please do not include medical details you would not want in an email — we will take those in the consultation.',
    'contact.form.submit': 'Send message',
    'contact.form.goesTo': 'Goes straight to {email}.',
    'contact.form.sentTitle': 'Thank you — your message is with us.',
    'contact.form.sentBody': 'We reply to {email} within one business day.',
    'contact.form.sentUrgent': 'If it is urgent, please call us:',
    'contact.form.sendAnother': 'Send another message',
    'contact.needMore': 'Please tell us a little more — at least a sentence.',
    'contact.tooSoon': 'We already have that message — we will reply shortly.',
    'contact.notSaved': 'We could not save your message. Please call the clinic.',
    'info.homeTitle': 'Conditions, treatments and FAQ',
    'info.homeSub': 'Read about your care on our website',
    'info.title': 'Learn more',
    'info.lede':
        'Read about the conditions we treat, our treatments and what a visit is like. These pages open on the clinic\'s website.',
    'info.urduNote':
        'To read these pages in Urdu, choose اردو on the website once — it will remember your choice.',
    'info.conditions': 'Conditions',
    'info.conditionsSub': 'Depression, anxiety, OCD, hair loss, acne scars and more',
    'info.treatments': 'Treatments',
    'info.treatmentsSub': 'Psychiatric care, ketamine therapy, Botox, fillers, PRP',
    'info.telemedicine': 'Telemedicine',
    'info.telemedicineSub': 'How an online consultation works',
    'info.whatToExpect': 'What to expect',
    'info.whatToExpectSub': 'Your first visit, step by step',
    'info.faq': 'Frequently asked questions',
    'info.faqSub': 'Fees, timings, privacy and more',
    'info.about': 'About the clinic',
    'info.aboutSub': 'Who we are and how we work',
    'info.blog': 'Blog',
    'info.blogSub': 'Articles from our doctors',
    'info.stillQuestions': 'Still have a question?',

    'lang.english': 'English',
    'lang.urdu': 'اردو',
  };

  static const ur = <String, String>{
    'app.name': 'ٹی ایل سی میڈ کلینکس',
    'app.tagline': 'ذہنی صحت اور جلد کی دیکھ بھال، ایک ہی چھت کے نیچے۔',

    'common.retry': 'دوبارہ کوشش کریں',
    'common.cancel': 'منسوخ کریں',
    'common.save': 'محفوظ کریں',
    'common.close': 'بند کریں',
    'common.back': 'واپس',
    'common.next': 'آگے',
    'common.confirm': 'تصدیق کریں',
    'common.done': 'مکمل',
    'common.loading': 'لوڈ ہو رہا ہے…',
    'common.offline': 'لگتا ہے آپ آف لائن ہیں۔',
    'common.somethingWrong': 'کچھ گڑبڑ ہو گئی۔',
    'common.callClinic': 'کلینک کو کال کریں',
    'common.whatsapp': 'واٹس ایپ',
    'common.optional': 'اختیاری',
    'common.seeAll': 'سب دیکھیں',
    'common.nothingHere': 'ابھی یہاں کچھ نہیں',
    'common.signInRequired': 'دیکھنے کے لیے سائن اِن کریں۔',

    'nav.home': 'ہوم',
    'nav.appointments': 'بُکنگ',
    'nav.services': 'خدمات',
    'nav.alerts': 'اطلاعات',
    'nav.profile': 'پروفائل',

    'auth.signIn': 'سائن اِن',
    'auth.signOut': 'سائن آؤٹ',
    'auth.createAccount': 'اکاؤنٹ بنائیں',
    'auth.haveAccount': 'پہلے سے اکاؤنٹ ہے؟',
    'auth.noAccount': 'اکاؤنٹ نہیں ہے؟',
    'auth.name': 'پورا نام',
    'auth.phone': 'فون نمبر',
    'auth.email': 'ای میل',
    'auth.password': 'پاس ورڈ',
    'auth.forgot': 'پاس ورڈ بھول گئے؟',
    'auth.resetSent': 'پاس ورڈ بحال کرنے کا ای میل بھیج دیا گیا۔',
    'auth.withEmail': 'ای میل',
    'auth.withPhone': 'فون',
    'auth.sendCode': 'کوڈ بھیجیں',
    'auth.invalidPhone': 'یہ فون نمبر درست معلوم نہیں ہوتا۔',
    'auth.invalidCode': 'کوڈ درست نہیں۔ دوبارہ کوشش کریں۔',
    'auth.codeExpired': 'کوڈ کی مدت ختم ہو گئی — نیا کوڈ منگوائیں۔',
    'auth.tooManyRequests': 'بہت زیادہ کوششیں۔ چند منٹ بعد کوشش کریں۔',
    'auth.resendTooSoon': 'نیا کوڈ منگوانے سے پہلے تھوڑا انتظار کریں۔',
    'auth.smsFailed': 'کوڈ نہیں بھیجا جا سکا۔ دوبارہ کوشش کریں یا ای میل استعمال کریں۔',
    'auth.smsNotConfigured':
        'فون سے داخلہ ابھی ترتیب نہیں دیا گیا۔ فی الحال ای میل استعمال کریں۔',
    'net.timeout':
        'کلینک کے سرور نے جواب دینے میں بہت دیر لگا دی۔ اپنا انٹرنیٹ دیکھ کر دوبارہ کوشش کریں۔',
    'net.offline': 'انٹرنیٹ نہیں ہے۔ کنیکشن دیکھ کر دوبارہ کوشش کریں۔',
    'net.dropped': 'رابطہ منقطع ہو گیا۔ دوبارہ کوشش کریں۔',
    'net.unreadable': 'سرور نے ایسا جواب دیا جو ایپ سمجھ نہیں سکی۔',
    'net.signInAgain': 'براہِ کرم دوبارہ سائن اِن کریں۔',
    'net.forbidden': 'آپ کو یہ کام کرنے کی اجازت نہیں۔',
    'net.notFound': 'یہ اب موجود نہیں ہے۔',
    'net.conflict': 'کوئی اور آپ سے پہلے کر چکا ہے۔ دوبارہ کوشش کریں۔',
    'net.serverProblem': 'کلینک کے سرور میں مسئلہ آ گیا۔ دوبارہ کوشش کریں۔',
    'net.generic': 'کچھ غلط ہو گیا۔ دوبارہ کوشش کریں۔',
    'net.cannotOpen': 'اس فون میں ایسی کوئی ایپ نہیں جو یہ کھول سکے۔',
    'net.notSaved': 'تبدیلی محفوظ نہیں ہوئی۔ دوبارہ کوشش کریں۔',
    'auth.googleNoAccount': 'گوگل سے سائن اِن ہو گیا، مگر کوئی اکاؤنٹ واپس نہیں آیا۔',
    'sess.inPerson': 'کلینک میں ملاقات',
    'sess.cancelled': 'منسوخ',
    'sess.awaitingConfirmation': 'تصدیق کا انتظار',
    'sess.awaitingPayment': 'مریض کی ادائیگی کا انتظار',
    'sess.ended': 'سیشن ختم ہو گیا',
    'sess.live': 'ابھی جاری ہے',
    'sess.scheduled': 'طے شدہ',
    'sess.readyToJoin': 'شامل ہونے کے لیے تیار',
    'sess.startingSoon': 'ابھی شروع ہونے والا ہے',
    'sess.startsInMin': '{n} منٹ میں شروع',
    'sess.startsInHours': '{n} گھنٹے میں شروع',
    'auth.invalidEmail': 'یہ ای میل درست معلوم نہیں ہوتی۔',
    'auth.wrongCredentials': 'ای میل یا پاس ورڈ درست نہیں۔',
    'auth.signInFailed': 'سائن اِن نہیں ہو سکا۔',
    'auth.emailInUse': 'اس ای میل پر پہلے سے اکاؤنٹ موجود ہے۔ سائن اِن کر کے دیکھیں۔',
    'auth.registerFailed': 'اکاؤنٹ نہیں بن سکا۔',
    'auth.noUserReturned': 'اکاؤنٹ بن گیا مگر صارف واپس نہیں آیا۔',
    'auth.googleNotSetUp':
        'اس بلڈ کے لیے گوگل سائن اِن ابھی ترتیب نہیں دیا گیا — فائربیس کنسول میں ایپ کا SHA-1 شامل کرنا ہو گا۔',
    'rate.care': 'دیکھ بھال کا معیار',
    'rate.listening': 'بات سننا اور توجہ دینا',
    'rate.courtesy': 'عملے کا رویہ',
    'rate.efficiency': 'انتظار کا وقت',
    'rate.recommend': 'سفارش کریں گے',
    'auth.enterCode': 'چھ ہندسوں کا کوڈ درج کریں',
    'auth.codeSentTo': 'ہم نے کوڈ بھیجا ہے',
    'auth.verify': 'تصدیق کریں',
    'auth.resend': 'دوبارہ بھیجیں',
    'auth.blocked': 'یہ اکاؤنٹ معطل کر دیا گیا ہے۔ براہِ کرم کلینک کو کال کریں۔',
    'auth.welcome': 'خوش آمدید',
    'auth.welcomeSub': 'اپائنٹمنٹ بُک کرنے کے لیے سائن اِن کریں۔',
    'auth.createSub': 'چند تفصیلات، اور آپ ابھی بُکنگ کر سکتی ہیں۔',
    'auth.browse': 'صرف دیکھنا ہے',
    'auth.needName': 'براہِ کرم اپنا نام لکھیں۔',
    'auth.needEmail': 'براہِ کرم اپنا ای میل لکھیں۔',
    'auth.needPassword': 'پاس ورڈ کم از کم چھ حروف کا ہونا چاہیے۔',
    'auth.needPhone': 'یہ فون نمبر درست نہیں لگتا۔',
    'auth.phoneHelp': 'ہم آپ کو چھ ہندسوں کا کوڈ بھیجیں گے۔',
    'auth.or': 'یا',
    'auth.continueWithGoogle': 'گوگل سے جاری رکھیں',
    'auth.googleFailed': 'گوگل سے سائن اِن نہیں ہو سکا۔ دوبارہ کوشش کریں۔',
    'auth.imPatient': 'میں مریض ہوں',
    'auth.imDoctor': 'میں ڈاکٹر ہوں',
    'auth.patientIntro':
        'اپائنٹمنٹ بُک کریں، اپنے نسخے دیکھیں، اور سب کچھ ایک ہی جگہ رکھیں۔',
    'auth.doctorIntro':
        'کلینک میں شامل ہونے کی درخواست دیں۔ ہر درخواست ایڈمن دیکھتا ہے، اس لیے '
            'منظوری تک آپ کا اکاؤنٹ غیر فعال رہے گا۔',
    'auth.specializationHint': 'مثلاً نفسیات',
    'auth.doctorPending':
        'اکاؤنٹ بن گیا۔ ڈاکٹر کے طور پر شامل ہونے کی آپ کی درخواست ایڈمن کی منظوری '
            'کی منتظر ہے — جائزے کے بعد ہم آپ کو اطلاع دیں گے۔',
    'auth.confirmPassword': 'پاس ورڈ دوبارہ لکھیں',
    'auth.passwordsDontMatch': 'دونوں پاس ورڈ ایک جیسے نہیں ہیں۔',
    'auth.doctorNeedsEmail':
        'ڈاکٹر کا اکاؤنٹ ای میل کے ساتھ بنتا ہے، تاکہ کلینک آپ کی درخواست کے بارے '
            'میں آپ سے رابطہ کر سکے۔',
    'auth.doctorLoginIntro':
        'اپنے کلینک اکاؤنٹ میں سائن اِن کریں — آپ کا شیڈول، آپ کے مریض، اور ان '
            'کے نسخے۔',
    'auth.rolePatientActually':
        'یہ اکاؤنٹ مریض کے طور پر رجسٹرڈ ہے، اس لیے ہم آپ کو وہیں لے جا رہے ہیں۔',
    'auth.roleDoctorActually':
        'یہ اکاؤنٹ ڈاکٹر کے طور پر رجسٹرڈ ہے، اس لیے ہم آپ کو وہیں لے جا رہے ہیں۔',
    'auth.roleAdminActually':
        'یہ ایڈمن اکاؤنٹ ہے، اس لیے ہم آپ کو وہیں لے جا رہے ہیں۔',
    'auth.verifyTitle': 'ای میل کی تصدیق',
    'auth.verifyHeading': 'بس ایک قدم اور',
    'auth.verifySentTo': 'ہم نے تصدیقی لنک بھیج دیا ہے',
    'auth.verifyStep1': 'وہ ای میل کھول کر اُس میں دیے گئے لنک پر کلک کریں۔',
    'auth.verifyStep2': 'پھر یہاں واپس آ جائیں — ایپ خود آپ کو اندر لے آئے گی۔',
    'auth.verifySpam': 'نظر نہ آئے تو اسپَیم یا جنک فولڈر دیکھ لیں۔',
    'auth.verifyDone': 'کر لیا — اب چیک کریں',
    'auth.verifyResend': 'ای میل دوبارہ بھیجیں',
    'auth.verifyResent': 'بھیج دی گئی۔ پہنچنے میں ایک منٹ لگ سکتا ہے۔',
    'auth.verifyNotYet':
        'ابھی تصدیق نہیں ہوئی۔ پہلے ای میل میں دیے گئے لنک پر کلک کریں۔',
    'auth.verifyThanks': 'ای میل کی تصدیق ہو گئی۔ خوش آمدید۔',
    'auth.verifyTooMany':
        'ابھی بہت سی ای میلز بھیجی جا چکی ہیں۔ چند منٹ انتظار کر لیں۔',
    'auth.verifyFailed': 'ای میل نہیں بھیجی جا سکی۔ دوبارہ کوشش کریں۔',
    'auth.verifyWrongEmail': 'ای میل غلط ہے، یا یہ آپ کا اکاؤنٹ نہیں؟',

    'splash.checking': 'تیاری ہو رہی ہے…',

    'home.greeting': 'السلام علیکم',
    'home.guest': 'جی',
    'home.book': 'اپائنٹمنٹ بُک کریں',
    'home.bookSub': 'خدمت اور وقت منتخب کریں',
    'home.upcoming': 'آپ کی اگلی اپائنٹمنٹ',
    'home.noUpcoming': 'کوئی آنے والی اپائنٹمنٹ نہیں',
    'home.noUpcomingSub': 'بُک کرنے پر یہاں نظر آئے گی۔',
    'home.ourServices': 'ہماری خدمات',
    'home.ourDoctors': 'ہمارے ڈاکٹرز',
    'home.callSub': 'ابھی کلینک سے بات کریں',

    'services.title': 'خدمات',
    'services.empty': 'کلینک نے ابھی کوئی خدمت شائع نہیں کی۔',
    'services.whatsIncluded': 'کیا شامل ہے',
    'services.treatments': 'علاج',
    'services.duration': 'دورانیہ',
    'services.minutes': 'منٹ',
    'services.price': 'قیمت',
    'services.advance': 'ابھی ادا کریں',
    'services.bookThis': 'یہ بُک کریں',

    'doctors.title': 'ڈاکٹرز',
    'doctors.empty': 'ابھی کوئی ڈاکٹر درج نہیں۔',
    'doctors.online': 'اِس وقت آن لائن',
    'doctors.offline': 'آف لائن',

    'book.title': 'اپائنٹمنٹ بُک کریں',
    'book.step1': 'خدمت منتخب کریں',
    'book.step2': 'آپ کس طرح ملنا چاہیں گی؟',
    'book.step3': 'وقت منتخب کریں',
    'book.step4': 'تصدیق',
    'book.online': 'آن لائن',
    'book.onlineSub': 'ویڈیو یا آڈیو کال',
    'book.inClinic': 'کلینک میں',
    'book.inClinicSub': 'لاہور میں ہم سے ملیں',
    'book.noSlots': 'اِس وقت کوئی خالی وقت دستیاب نہیں۔',

    'book.tryInClinic': 'اِس سروس کے لیے کلینک میں {n} اوقات خالی ہیں۔',
    'book.tryOnline': 'اِس سروس کے لیے آن لائن {n} اوقات خالی ہیں۔',
    'book.switchInClinic': 'کلینک وزٹ کے اوقات دیکھیں',
    'book.switchOnline': 'آن لائن اوقات دیکھیں',
    'book.noSlotsSub': 'آپ کلینک سے وقت طے کرنے کی درخواست کر سکتی ہیں — وہ آپ کو کال کریں گے۔',
    'book.requestInstead': 'کلینک سے وقت طے کرنے کی درخواست کریں',
    'book.preferredWhen': 'آپ کو کون سا وقت مناسب رہے گا؟',
    'book.preferredWhenHint': 'مثلاً ہفتے کے دن صبح، یا شام چھ بجے کے بعد',
    'book.notes': 'ڈاکٹر کو کچھ بتانا چاہیں گی؟',
    'book.yourName': 'آپ کا نام',
    'book.yourPhone': 'آپ کا فون نمبر',
    'book.summary': 'بُکنگ کا خلاصہ',
    'book.service': 'خدمت',
    'book.doctor': 'ڈاکٹر',
    'book.when': 'کب',
    'book.howSeen': 'کیسے',
    'book.payLater': 'کلینک تصدیق اور ادائیگی کے لیے آپ کو کال کرے گا۔',
    'book.submit': 'اپائنٹمنٹ کی درخواست بھیجیں',
    'book.booked': 'بُک ہو گئی۔ کلینک جلد آپ کو کال کرے گا۔',
    'book.requested': 'درخواست بھیج دی گئی۔ کلینک جلد آپ کو کال کرے گا۔',
    'book.howPay': 'آپ ادائیگی کیسے کرنا چاہیں گی؟',
    'book.payNow': 'ابھی ادائیگی کریں',
    'book.payNowSub': 'ایڈوانس ابھی ادا کریں اور آپ کا وقت فوراً پکا ہو جائے گا۔',
    'book.payAtClinic': 'کلینک کی کال پر ادائیگی',
    'book.payAtClinicSub':
        'ہم آپ کا وقت روک لیں گے اور تصدیق کے لیے کال کریں گے۔ ابھی کچھ نہیں کٹے گا۔',
    'book.payable': 'ابھی قابلِ ادائیگی',
    'book.paid': 'ادائیگی ہو گئی۔ آپ کی اپائنٹمنٹ پکی ہے۔',
    'book.payFailed': 'ادائیگی مکمل نہیں ہوئی۔ آپ کا وقت واپس کھول دیا گیا ہے۔',
    'book.payCancelled': 'ادائیگی منسوخ کر دی گئی۔ کچھ بھی نہیں کاٹا گیا۔',
    'book.payAttention':
        'ہم ابھی آپ کی ادائیگی کی تصدیق نہیں کر سکے۔ آپ کا وقت اب بھی محفوظ ہے — دوبارہ ادائیگی سے پہلے کلینک کو کال کریں۔',
    'pay.secureNote': 'یہ صفحہ ادائیگی کے ادارے کا ہے۔ آپ کا کارڈ نہ کلینک تک پہنچتا ہے نہ اس ایپ تک۔',
    'pay.pageFailed': 'یہ صفحہ نہیں کھل سکا۔ اپنا انٹرنیٹ دیکھ کر دوبارہ کوشش کریں۔',
    'pay.leaveTitle': 'ادائیگی کے بغیر واپس جائیں؟',
    'pay.leaveBody':
        'اگر آپ کارڈ کی تفصیل دے چکی ہیں تو ذرا ٹھہر جائیں، عمل مکمل ہو جائے۔ '
            'ابھی واپس جانے پر منتخب کیا ہوا وقت چھوٹ جائے گا۔',
    'pay.keepPaying': 'یہیں رہیں',
    'pay.openingBrowser':
        'ادائیگی کا صفحہ آپ کے براؤزر میں کھولا جا رہا ہے…',
    'pay.openingGateway': 'آپ کو ادائیگی کے صفحے پر لے جایا جا رہا ہے…',
    'appt.joinNotReady':
        'سیشن کا کمرہ ابھی نہیں کھلا۔ ایک لمحے بعد دوبارہ کوشش کریں۔',
    'pay.leave': 'واپس جائیں',
    'pay.openInBrowser': 'براؤزر میں کھولیں',
    'pay.browserUnavailable':
        'یہ طریقۂ ادائیگی صرف ایپ کے اندر ہی مکمل ہو سکتا ہے۔',
    'pay.inBrowser':
        'ادائیگی کا صفحہ آپ کے براؤزر میں کھل گیا ہے۔ وہاں ادائیگی مکمل کریں، پھر واپس آ کر صفحہ نیچے کھینچ کر تازہ کریں — ادائیگی منظور ہوتے ہی آپ کی اپائنٹمنٹ نظر آ جائے گی۔',
    'pay.chooseMethod': 'آپ کس طرح ادائیگی کرنا چاہیں گے؟',
    'pay.confirmAndPay': 'تصدیق کریں اور ادائیگی کریں',
    'pay.dueNow': 'ابھی قابلِ ادائیگی',
    'pay.noMethods':
        'آن لائن ادائیگی ابھی دستیاب نہیں۔ اس وقت کی تصدیق کے لیے کلینک کو کال کریں۔',
    'pay.holdNote':
        'یہ وقت ادائیگی تک آپ کے لیے محفوظ ہے۔ ادائیگی ادارے کے اپنے محفوظ صفحے پر مکمل ہوتی ہے۔',

    'appt.title': 'اپائنٹمنٹس',

    'range.from': 'اس تاریخ سے',
    'range.to': 'اس تاریخ تک',
    'range.today': 'آج',
    'range.week': 'پچھلے 7 دن',
    'range.month': 'پچھلے 30 دن',
    'range.upcoming': 'اگلے 30 دن',
    'range.clear': 'تاریخیں ہٹائیں',
    'range.matched': 'ان تاریخوں میں',
    'range.empty': 'ان تاریخوں میں کوئی اپائنٹمنٹ نہیں۔',
    'appt.upcoming': 'آنے والی',
    'appt.past': 'گزشتہ',
    'appt.empty': 'ابھی کوئی اپائنٹمنٹ نہیں۔',
    'appt.emptySub': 'بُک کریں تو یہاں نظر آئے گی۔',
    'appt.status.pending': 'کلینک کی کال کا انتظار',
    'appt.status.awaiting-payment': 'آپ کی ادائیگی کا انتظار',
    'appt.statusStaff.awaiting-payment': 'ادائیگی کا انتظار',
    'appt.status.confirmed': 'تصدیق شدہ',
    'appt.status.completed': 'مکمل',
    'appt.status.cancelled': 'منسوخ',
    'appt.needsDoctor': 'کلینک ڈاکٹر مقرر کر رہا ہے',
    'appt.notScheduled': 'وقت ابھی طے نہیں ہوا',
    'appt.details': 'اپائنٹمنٹ',
    'appt.prescription': 'نسخہ',
    'appt.noPrescription': 'ابھی کوئی نسخہ درج نہیں کیا گیا۔',
    'appt.joinCall': 'کال میں شامل ہوں',
    'appt.cancel': 'یہ اپائنٹمنٹ منسوخ کریں',
    'appt.cancelConfirm': 'اپائنٹمنٹ منسوخ کر دیں؟',
    'appt.cancelConfirmSub': 'یہ وقت کسی اور کے لیے کھول دیا جائے گا۔',
    'appt.cancelled': 'اپائنٹمنٹ منسوخ ہو گئی۔',
    'appt.keepIt': 'رہنے دیں',
    'appt.amount': 'رقم',
    'appt.paid': 'ادا شدہ',
    'appt.unpaid': 'ادا نہیں کی گئی',
    'appt.bookedOn': 'بُک ہوئی',
    'appt.rate': 'اس ملاقات کی رائے دیں',
    'appt.yourRating': 'آپ کی رائے',

    'alerts.title': 'اطلاعات',
    'alerts.empty': 'کوئی اطلاع نہیں۔',
    'alerts.emptySub': 'یاد دہانیاں اور تصدیقیں یہاں نظر آئیں گی۔',
    'alerts.markAllRead': 'سب کو پڑھا ہوا نشان زد کریں',

    'profile.title': 'پروفائل',
    'profile.editName': 'نام',
    'profile.unnamedPatient': 'مریض',
    'profile.language': 'زبان',
    'profile.contact': 'کلینک سے رابطہ',
    'profile.saved': 'محفوظ ہو گیا۔',
    'profile.diagnostics': 'کنکشن کی جانچ',
    'profile.signOutConfirm': 'اس ڈیوائس سے سائن آؤٹ کر دیں؟',

    'staff.title': 'عملہ',
    'staff.doctorSub': 'آج آپ کے لیے مقرر اپائنٹمنٹس۔',
    'staff.adminSub': 'ایڈمن پینل فی الحال ویب سائٹ پر ہے۔',
    'staff.openWebsite': 'ویب سائٹ کھولیں',


    'common.edit': 'تبدیل کریں',

    'home.subtitle': 'نئی اپائنٹمنٹ بُک کریں، یا پرانی دیکھیں۔',
    'home.needHelp': 'مدد چاہیے؟',
    'home.ourDoctorsSub': 'دیکھیں آج کون دستیاب ہے',

    'services.search': 'خدمات تلاش کریں',
    'services.noMatch': 'اس سے کچھ نہیں ملا',
    'services.noMatchSub': 'چھوٹا لفظ آزمائیں، یا علاج کا نام لکھیں۔',

    'appt.emptyUpcoming': 'ابھی کوئی بُکنگ نہیں',
    'appt.emptyPast': 'کوئی گزشتہ ملاقات نہیں',
    'appt.emptyPastSub': 'مکمل ہونے والی ملاقاتیں یہاں درج ہوں گی۔',

    'profile.account': 'آپ کی تفصیلات',
    'profile.preferences': 'ترجیحات',
    'profile.doctorDetails': 'ڈاکٹر پروفائل',
    'profile.developer': 'ڈویلپر',
    'profile.addName': 'اپنا نام لکھیں',
    'profile.tapToEdit': 'تبدیل کرنے کے لیے دبائیں',
    'profile.notSet': 'ابھی درج نہیں',
    'profile.emailLooksWrong': 'یہ ای میل درست نہیں لگتا۔',
    'profile.contactNote':
        'کلینک آپ کی اپائنٹمنٹ کے بارے میں انہی پر رابطہ کرتا ہے۔ یہاں تبدیلی سے سائن اِن کا طریقہ نہیں بدلتا۔',
    'profile.notificationSound': 'اطلاع کی آواز',
    'profile.notificationSoundSub': 'کلینک کی اطلاع پر آواز آئے',
    'profile.messageSound': 'پیغام کی آواز',
    'profile.messageSoundSub': 'چیٹ پیغامات کی آواز',
    'profile.specialization': 'تخصص',
    'profile.bio': 'آپ کے بارے میں',
    'profile.showOnline': 'مجھے آن لائن دکھائیں',
    'profile.showOnlineSub': 'مریض دیکھ سکیں گے کہ آپ دستیاب ہیں',
    'profile.emailUs': 'ای میل کریں',
    'profile.signOutPartial': 'اس فون سے سائن آؤٹ ہو گیا، مگر سرور سے رابطہ نہیں ہوا۔',

    'doc.nav.overview': 'خلاصہ',
    'doc.nav.appointments': 'ملاقاتیں',
    'doc.nav.availability': 'میرے اوقات',
    'doc.nav.patients': 'مریض',

    'doc.overview.title': 'ڈاکٹر',
    'doc.overview.hello': 'السلام علیکم',
    'doc.overview.subtitle': 'آپ کا دن، اور جو کام آپ کے منتظر ہیں۔',
    'doc.overview.today': 'آج کا شیڈول',
    'doc.overview.nothingToday': 'آج شیڈول میں کچھ نہیں۔',
    'doc.presence.on': 'مریض دیکھ سکتے ہیں کہ آپ آن لائن ہیں',
    'doc.presence.hidden': 'آپ مریضوں سے پوشیدہ ہیں',
    'doc.presence.change': 'تبدیل کریں',
    'doc.stat.today': 'آج کی نشستیں',
    'doc.stat.upcoming': 'آنے والی تصدیق شدہ',
    'doc.stat.patients': 'میرے مریض',
    'doc.stat.completed': 'مکمل',

    'doc.appointments.title': 'اپائنٹمنٹس',
    'doc.appointments.search': 'مریض، خدمت یا تاریخ تلاش کریں',
    'doc.appointments.empty': 'یہاں کوئی اپائنٹمنٹ نہیں۔',
    'doc.filter.all': 'سب',
    'doc.markAs': 'حیثیت',
    'doc.updated': 'تبدیلی محفوظ ہو گئی۔',
    'doc.joinAsHost': 'میزبان کے طور پر شامل ہوں',
    'doc.openChat': 'محفوظ چیٹ کھولیں',
    'doc.startEarly': 'جلد شروع کریں',
    'doc.connecting': 'جوڑا جا رہا ہے…',
    'doc.endSession': 'نشست ختم کریں',
    'doc.endSessionSub': 'اس سے کال سب کے لیے ختم ہو جائے گی اور ملاقات مکمل شمار ہو گی۔',
    'doc.sessionEnded': 'نشست ختم ہو گئی۔',
    'doc.addPrescription': 'نسخہ',
    'doc.editPrescription': 'نسخہ',
    'doc.followUp': 'اگلی ملاقات',

    'doc.rx.text': 'نسخہ',
    'doc.rx.hint': 'دوائیں، مقدار، ہدایات…',
    'doc.rx.images': 'تصاویر',
    'doc.rx.add': 'شامل کریں',
    'doc.rx.addImage': 'تصویر کا لنک لگائیں',
    'doc.rx.noImages':
        'کوئی تصویر منسلک نہیں۔ ویب سائٹ پر پہلے سے اپلوڈ کی گئی تصویر کا لنک یہاں لگا سکتے ہیں۔',
    'doc.rx.badUrl': 'یہ لنک نہیں لگتا۔',
    'doc.rx.maxImages': 'زیادہ سے زیادہ چھ تصاویر۔',
    'doc.rx.needSomething': 'نسخہ لکھیں، یا اس کی تصویر منسلک کریں۔',
    'doc.rx.save': 'نسخہ محفوظ کریں',
    'doc.rx.saved': 'نسخہ محفوظ ہو گیا۔',
    'doc.rx.visibleNote': 'محفوظ کرتے ہی مریض کو نظر آ جائے گا۔',

    'doc.fu.after': 'اس کے بعد',
    'doc.fu.pickTime': 'اپنے کیلنڈر سے وقت منتخب کریں',
    'doc.fu.noSlots': 'آپ کا کوئی وقت کھلا نہیں۔',
    'doc.fu.noSlotsSub': '"میرے اوقات" میں وقت کھولیں، پھر یہاں واپس آئیں۔',
    'doc.fu.note': 'مریض کے لیے نوٹ',
    'doc.fu.noteHint': 'یہ اگلی ملاقات کس لیے ہے',
    'doc.fu.pickFirst': 'پہلے وقت منتخب کریں',
    'doc.fu.book': 'بُک کریں',
    'doc.fu.booked': 'اگلی ملاقات بُک ہو گئی۔ مریض سے ادائیگی کا کہا گیا ہے۔',
    'doc.fu.paymentNote':
        'ادائیگی تک یہ وقت مریض کے لیے محفوظ رہے گا۔ مدت گزر جائے تو وقت خود بخود کھل جائے گا۔',

    'doc.av.title': 'میری دستیابی',
    'doc.av.subtitle': 'جن اوقات میں مریض دیکھ سکتی ہیں وہ کھولیں، اور چھٹی کے دن درج کریں۔',
    'doc.av.addTimes': 'اوقات کھولیں',
    'doc.av.day': 'دن',
    'doc.av.from': 'سے',
    'doc.av.to': 'تک',
    'doc.av.each': 'ہر اپائنٹمنٹ کا دورانیہ',
    'doc.av.service': 'کس خدمت کے لیے؟',
    'doc.av.anyService': 'کوئی بھی خدمت',
    'doc.av.willOpen': 'اوقات کھلیں گے:',
    'doc.av.noneFit': 'ان دو اوقات کے درمیان کوئی اپائنٹمنٹ نہیں سماتی۔',
    'doc.av.openThem': 'یہ اوقات کھولیں',
    'doc.av.opened': 'اوقات کھل گئے۔',
    'doc.av.myTimes': 'میرے اوقات',
    'doc.av.noTimes': 'ابھی کوئی وقت کھلا نہیں',
    'doc.av.noTimesSub': 'کچھ اوقات کھولیں تاکہ مریض بُک کر سکیں۔',
    'doc.av.booked': 'بُک شدہ',
    'doc.av.remove': 'ہٹائیں',
    'doc.av.removeTime': 'یہ وقت ہٹا دیں؟',
    'doc.av.removeTimeSub': 'مریضوں کو یہ وقت نظر نہیں آئے گا۔',
    'doc.av.daysAway': 'چھٹی کے دن',
    'doc.av.daysAwaySub':
        'چھٹی درج کرنے سے ان دنوں کے کھلے اوقات ہٹ جائیں گے اور نئے شامل نہیں ہو سکیں گے۔',
    'doc.av.markAway': 'چھٹی درج کریں',
    'doc.av.dates': 'تاریخیں',
    'doc.av.reason': 'وجہ',
    'doc.av.reasonHint': 'کانفرنس',
    'doc.av.noLeave': 'کوئی چھٹی درج نہیں۔',
    'doc.av.leaveSaved': 'چھٹی محفوظ ہو گئی۔',
    'doc.av.timesRemoved': 'کھلے اوقات ہٹا دیے گئے۔',
    'doc.av.leaveSavedBut':
        'چھٹی محفوظ ہو گئی، مگر ان بُک شدہ اپائنٹمنٹس کو کلینک کو دوبارہ طے کرنا ہو گا:',
    'doc.av.removeLeave': 'یہ چھٹی ہٹا دیں؟',
    'doc.av.removeLeaveSub':
        'وہ دن دوبارہ کھل جائیں گے۔ جو اوقات ہٹے تھے وہ واپس نہیں آئیں گے — دوبارہ شامل کرنے ہوں گے۔',

    'doc.patients.title': 'مریض',
    'doc.patients.one': 'مریض',
    'doc.patients.search': 'نام یا نمبر سے تلاش کریں',
    'doc.patients.empty': 'ابھی کوئی مریض نہیں۔',
    'doc.patients.sessions': 'ملاقاتیں',
    'doc.patients.lastSeen': 'آخری ملاقات',
    'doc.patients.next': 'اگلی نشست',
    'doc.patients.totalWithYou': 'آپ کے ساتھ ملاقاتیں',
    'doc.patients.history': 'ملاقاتوں کی تاریخ',
    'doc.patients.noRecord': 'کوئی ریکارڈ نہیں ملا',
    'doc.patients.noRecordSub': 'شاید یہ مریض اب آپ کے پاس نہیں۔',

    'adm.nav.doctors': 'ڈاکٹرز',
    'adm.nav.catalogue': 'فہرست',

    'adm.overview.title': 'کلینک',
    'adm.overview.clinic': 'کلینک',
    'adm.overview.recent': 'حالیہ',
    'adm.overview.days': 'دن',
    'adm.overview.callBacks': 'بُکنگز کو کال درکار',
    'adm.overview.callBacksSub': 'مریض کلینک کی تصدیق کے منتظر',
    'adm.overview.byQuestion': 'مریض کس بات پر کم نمبر دیتے ہیں',
    'adm.overview.byQuestionSub':
        'مجموعی اوسط یہ نہیں بتا سکتی کہ ملاقات کا کون سا حصہ کمزور ہے۔ یہ پانچ بتا سکتے ہیں۔',
    'adm.overview.byDoctor': 'ڈاکٹر کے حساب سے',
    'adm.overview.noRatings': 'ابھی کوئی رائے نہیں',
    'adm.stat.patients': 'مریض',
    'adm.stat.appointments': 'اپائنٹمنٹس',
    'adm.stat.services': 'خدمات',
    'adm.stat.blogs': 'مضامین',
    'adm.stat.revenue': 'وصول شدہ',
    'adm.stat.refunded': 'واپس کی گئی',
    'adm.stat.completed': 'مکمل ملاقاتیں',
    'adm.stat.completedLower': 'مکمل',
    'adm.stat.rating': 'اوسط درجہ',

    'adm.appt.title': 'تمام بُکنگز',
    'adm.appt.search': 'مریض، ڈاکٹر، خدمت یا تاریخ',
    'adm.appt.noDoctor': 'کوئی ڈاکٹر مقرر نہیں',
    'adm.appt.needsDoctor': 'ڈاکٹر درکار',
    'adm.appt.needsDoctorSub':
        'اس خدمت کے کسی ڈاکٹر کے پاس وقت خالی نہیں تھا۔ ڈاکٹر مقرر کریں، پھر وقت طے کریں۔',
    'adm.appt.assign': 'ڈاکٹر مقرر کریں',
    'adm.appt.assigned': 'مقرر کیا گیا:',
    'adm.appt.reschedule': 'وقت بدلیں',
    'adm.appt.pickNewTime': 'نیا وقت منتخب کریں',
    'adm.appt.rescheduled': 'وقت بدل دیا گیا۔ مریض اور ڈاکٹر کو اطلاع دے دی گئی۔',
    'adm.appt.noSlotsSub': 'اس ڈاکٹر کا کوئی وقت کھلا نہیں۔ ان سے کہیں کہ وقت کھولیں۔',
    'adm.appt.refund': 'رقم واپس کریں',
    'adm.appt.refundTitle': 'رقم واپس کر دیں؟',
    'adm.appt.refundSub':
        'یہ اصل رقم پیمنٹ فراہم کنندہ کے ذریعے واپس بھیجتا ہے۔ یہاں سے واپس نہیں کیا جا سکتا۔',
    'adm.appt.refunded': 'رقم واپس بھیج دی گئی۔',
    'adm.appt.awaitingRefund': 'منسوخ اور ادا شدہ — رقم واپسی باقی',

    'adm.doc.title': 'ڈاکٹرز',
    'adm.doc.all': 'تمام ڈاکٹرز',
    'adm.doc.pending': 'منظوری کے منتظر',
    'adm.doc.pendingSub':
        'آپ کے فیصلے تک نہ یہ سائن اِن کر سکتے ہیں نہ بُک ہو سکتے ہیں۔ انہیں پتہ نہیں چلتا کہ آپ دیکھ رہی ہیں۔',
    'adm.doc.approve': 'منظور کریں',
    'adm.doc.approved': 'منظور ہو گیا۔ اب یہ سائن اِن کر سکتے ہیں۔',
    'adm.doc.reject': 'مسترد کریں',
    'adm.doc.rejected': 'مسترد کر دیا گیا۔',
    'adm.doc.rejectTitle': 'یہ درخواست مسترد کر دیں؟',
    'adm.doc.rejectSub': 'ان کا سائن اِن بند ہو جائے گا۔ بعد میں منظور بھی کر سکتی ہیں۔',
    'adm.doc.rejectedTag': 'مسترد',
    'adm.doc.activeTag': 'فعال',
    'adm.doc.suspendedTag': 'معطل',
    'adm.doc.suspend': 'معطل کریں',
    'adm.doc.suspendTitle': 'اس ڈاکٹر کو معطل کر دیں؟',
    'adm.doc.suspendSub':
        'یہ فوراً سائن آؤٹ ہو جائیں گے اور مریضوں سے پوشیدہ۔ ان کی اپائنٹمنٹس برقرار رہیں گی۔',
    'adm.doc.reinstate': 'بحال کریں',
    'adm.doc.add': 'ڈاکٹر شامل کریں',
    'adm.doc.addSub':
        'اکاؤنٹ بن کر فوراً منظور ہو جاتا ہے۔ پاس ورڈ انہیں دے دیں، اور بدلنے کو کہیں۔',
    'adm.doc.create': 'اکاؤنٹ بنائیں',
    'adm.doc.created': 'ڈاکٹر شامل ہو گئے۔',
    'adm.doc.tempPassword': 'ابتدائی پاس ورڈ',
    'adm.doc.tempPasswordHelp': 'پہلی بار یہ سائن اِن کے لیے استعمال ہوگا۔',
    'adm.doc.needPassword': 'پاس ورڈ کم از کم آٹھ حروف کا ہونا چاہیے۔',

    'adm.cat.title': 'فہرست',
    'adm.cat.services': 'خدمات',
    'adm.cat.coupons': 'کوڈز',
    'adm.cat.blog': 'بلاگ',
    'adm.cat.newService': 'نئی خدمت',
    'adm.cat.newCoupon': 'نیا کوڈ',
    'adm.cat.newPost': 'نیا مضمون',
    'adm.cat.urdu': 'اردو',
    'adm.cat.delete': 'حذف کریں',
    'adm.cat.open': 'کھولیں',
    'adm.cat.deleteService': 'یہ خدمت حذف کر دیں؟',
    'adm.cat.deleteServiceSub':
        'یہ ویب سائٹ اور ایپ دونوں سے ہٹ جائے گی۔ پہلے سے بُک اپائنٹمنٹس پر اثر نہیں پڑے گا۔',
    'adm.cat.noCoupons': 'کوئی رعایتی کوڈ نہیں',
    'adm.cat.noCouponsSub': 'ایک بنائیں تو مریض ادائیگی کے وقت درج کر سکیں گے۔',
    'adm.cat.liveTag': 'فعال',
    'adm.cat.switchedOff': 'بند',
    'adm.cat.expiredTag': 'مدت ختم',
    'adm.cat.usedUp': 'حد ختم',
    'adm.cat.switchOff': 'بند کریں',
    'adm.cat.switchOn': 'چالو کریں',
    'adm.cat.off': 'رعایت',
    'adm.cat.used': 'استعمال',
    'adm.cat.until': 'تک',
    'adm.cat.deleteCoupon': 'یہ کوڈ حذف کر دیں؟',
    'adm.cat.deleteCouponSub': 'جس کے پاس یہ ہے اسے کام کرتا نہیں ملے گا۔',
    'adm.cat.code': 'کوڈ',
    'adm.cat.codeHelp': 'مریض ادائیگی کے وقت یہی لکھتے ہیں۔ بڑے حروف میں محفوظ ہوگا۔',
    'adm.cat.percent': 'فیصد',
    'adm.cat.flat': 'مقررہ',
    'adm.cat.percentOff': 'کتنے فیصد رعایت',
    'adm.cat.rupeesOff': 'کتنے روپے رعایت',
    'adm.cat.maxUses': 'کتنی بار استعمال ہو سکتا ہے',
    'adm.cat.noExpiry': 'کوئی آخری تاریخ نہیں',
    'adm.cat.createCoupon': 'کوڈ بنائیں',
    'adm.cat.needCode': 'کوڈ کا نام لکھیں۔',
    'adm.cat.needValue': 'رعایت کی مقدار لکھیں۔',
    'adm.cat.percentTooBig': 'فیصد سو سے زیادہ نہیں ہو سکتا۔',
    'adm.cat.noPosts': 'ابھی کوئی مضمون نہیں',
    'adm.cat.published': 'شائع شدہ',
    'adm.cat.draft': 'مسودہ',
    'adm.cat.publish': 'شائع کریں',
    'adm.cat.unpublish': 'شائع سے ہٹائیں',
    'adm.cat.deletePost': 'یہ مضمون حذف کر دیں؟',
    'adm.cat.deletePostSub': 'یہ ویب سائٹ سے ہٹ جائے گا۔',
    'adm.cat.postTitle': 'عنوان',
    'adm.cat.postExcerpt': 'مختصر خلاصہ',
    'adm.cat.postContent': 'مضمون',
    'adm.cat.publishNow': 'ابھی شائع کریں',
    'adm.cat.publishNowSub': 'بند رکھیں تو مسودے کے طور پر محفوظ ہوگا۔',
    'adm.cat.needTitleContent': 'مضمون کے لیے عنوان اور متن دونوں چاہئیں۔',
    'adm.cat.longFormNote':
        'لمبے مضامین اور اردو ترجمے کی سکرین ویب سائٹ پر کی بورڈ کے ساتھ آسان رہتی ہے۔',

    'adm.svc.edit': 'خدمت میں تبدیلی',
    'adm.svc.name': 'نام',
    'adm.svc.short': 'ایک سطر کا خلاصہ',
    'adm.svc.intro': 'مکمل تفصیل',
    'adm.svc.category': 'زمرہ',
    'adm.svc.categoryHelp': 'ویب سائٹ اور ایپ میں خدمات اسی کے حساب سے گروپ ہوتی ہیں۔',
    'adm.svc.onePerLine': 'ہر سطر میں ایک۔',
    'adm.svc.moneyTime': 'قیمت اور دورانیہ',
    'adm.svc.priceHelp': 'خالی چھوڑیں تو قیمت نہیں دکھائی جائے گی۔',
    'adm.svc.advanceHelp':
        'اپائنٹمنٹ محفوظ رکھنے کے لیے آن لائن لی جاتی ہے۔ خالی چھوڑیں تو پوری قیمت؛ صفر کا مطلب کچھ نہیں لیا جائے گا۔',
    'adm.svc.image': 'تصویر کا لنک',
    'adm.svc.imageHelp': 'Cloudinary کا URL، ویب سائٹ سے اپلوڈ کیا ہوا۔',
    'adm.svc.needNameCategory': 'خدمت کے لیے نام اور زمرہ دونوں چاہئیں۔',
    'adm.svc.saved': 'محفوظ ہو گیا۔',

    'auth.continueWithApple': 'Apple سے سائن اِن کریں',
    'auth.appleFailed': 'Apple سے سائن اِن نہیں ہو سکا۔ دوبارہ کوشش کریں۔',
    'auth.agreePrefix': 'اکاؤنٹ بنا کر آپ ہماری ',
    'auth.agreeAnd': ' اور ',
    'auth.agreeSuffix': ' سے اتفاق کرتے ہیں۔',

    'legal.title': 'قانونی معلومات',
    'legal.privacy': 'پرائیویسی پالیسی',
    'legal.terms': 'شرائطِ استعمال',
    'legal.refund': 'رقم واپسی کی پالیسی',

    'account.delete': 'اکاؤنٹ ختم کریں',
    'account.staffDelete':
        'ڈاکٹر اور ایڈمن کے اکاؤنٹ کلینک بند کرتا ہے۔ اپنا اکاؤنٹ بند کروانے کے لیے براہِ کرم کلینک سے رابطہ کریں۔',
    'account.deleteTitle': 'اپنا اکاؤنٹ ختم کر دیں؟',
    'account.deleteIntro': 'ایسا کرنے سے:',
    'account.deleteUpcoming':
        'آپ کی آنے والی اپائنٹمنٹس منسوخ ہو جائیں گی اور ان کا وقت کلینک کو واپس مل جائے گا۔ جو رقم پہلے ادا ہو چکی ہے وہ خود بخود واپس نہیں ہو گی — اگر آپ کو رقم واپس ملنی ہے تو پہلے کلینک سے رابطہ کریں۔',
    'account.deleteLogin':
        'آپ کا سائن اِن ختم ہو جائے گا، اور آپ کا نام، ای میل، فون اور تصویر پروفائل سے ہٹا دیے جائیں گے۔',
    'account.deleteNotifications': 'اس فون پر کلینک کی اطلاعات آنا بند ہو جائیں گی۔',
    'account.deleteRecords':
        'آپ کے پچھلے معائنے، نسخے اور ادائیگیاں کلینک کے پاس رہیں گی، کیونکہ طبی ریکارڈ رکھنا ضروری ہے، مگر ان پر آپ کا نام یا فون نمبر نہیں ہو گا۔',
    'account.deleteFinal': 'یہ عمل واپس نہیں ہو سکتا۔',
    'account.deleteTypePrompt': 'تصدیق کے لیے نیچے {word} لکھیں۔',
    'account.deleteWord': 'حذف',
    'account.deleteForever': 'ہمیشہ کے لیے ختم کریں',
    'account.deleting': 'آپ کا اکاؤنٹ ختم کیا جا رہا ہے…',
    'account.deleteFailed': 'آپ کا اکاؤنٹ ختم نہیں ہوا، اور آپ ابھی بھی سائن اِن ہیں۔',
    'account.deleted': 'آپ کا اکاؤنٹ ختم کر دیا گیا ہے۔',


    // ── Booking parity, contact and information (website parity) ──
    'book.newPatient': 'نیا مریض',
    'book.newPatientHint':
        'پہلی ملاقات ہے؟ نیچے سے خدمت منتخب کریں۔ اگر آپ کے پاس کوپن ہے تو آخری مرحلے پر لگا سکتی ہیں۔',
    'book.followUp': 'دوبارہ ملاقات',
    'book.followUpHint':
        'پہلے سے ہماری مریض ہیں؟ معمول کی دوبارہ ملاقات، یا 30 یا 60 منٹ کی طویل نشست بُک کریں۔',
    'book.noServicesType': 'اِس وقت اس قسم کی کوئی خدمت بُکنگ کے لیے دستیاب نہیں۔',
    'book.howToMeet': 'آپ کس طرح بات کرنا چاہیں گی؟',
    'mode.video': 'ویڈیو کال',
    'mode.audio': 'آڈیو کال',
    'mode.chat': 'چیٹ',
    'book.coupon': 'کوئی کوپن ہے؟',
    'book.couponPlaceholder': 'کوپن کوڈ (اختیاری)',
    'book.apply': 'لاگو کریں',
    'book.couponApplied': 'کوپن لاگو ہو گیا۔',
    'book.couponAppliedCode': '{code} لاگو ہو گیا',
    'book.couponSaving': '{discount} کی رعایت۔ ابھی آپ کو {total} ادا کرنے ہوں گے۔',
    'book.couponServerNote': 'حتمی قیمت بُکنگ کے وقت کلینک طے کرے گا۔',
    'book.couponRemove': 'ہٹائیں',
    'book.couponInvalid': 'یہ کوپن اس وقت درست نہیں ہے۔',
    'book.couponNotFound': 'یہ کوڈ ہمیں نہیں ملا۔',
    'book.couponInactive': 'یہ کوڈ اب فعال نہیں ہے۔',
    'book.couponExpired': 'اس کوڈ کی مدت ختم ہو چکی ہے۔',
    'book.couponUsedUp': 'یہ کوڈ جتنی بار استعمال ہو سکتا تھا، ہو چکا ہے۔',
    'book.couponNotForYou': 'یہ کوڈ اس اکاؤنٹ کے لیے نہیں ہے۔',
    'book.discount': 'رعایت',
    'book.priceChanged': 'اس بُکنگ کی کلینک کی طے شدہ قیمت {amount} ہے۔ آپ یہی رقم ادا کریں گی۔',
    'contact.title': 'کلینک سے رابطہ',
    'contact.homeSub': 'ہمیں پیغام میں اپنا سوال بھیجیں',
    'contact.form.lede':
        'کچھ بھی پوچھیں — فیس، اوقات، یا یہ کہ کوئی علاج آپ کے لیے مناسب ہے یا نہیں۔',
    'contact.form.name': 'نام',
    'contact.label.phone': 'فون',
    'contact.form.message': 'پیغام',
    'contact.form.messagePlaceholder': 'بتائیے، آپ کیا جاننا چاہتی ہیں۔',
    'contact.form.privacy':
        'براہِ کرم ایسی طبی تفصیلات نہ لکھیں جو آپ ای میل میں نہیں بھیجنا چاہتیں — وہ باتیں ہم ملاقات کے دوران سن لیں گے۔',
    'contact.form.submit': 'پیغام بھیجیں',
    'contact.form.goesTo': 'یہ پیغام سیدھا {email} پر پہنچتا ہے۔',
    'contact.form.sentTitle': 'شکریہ — آپ کا پیغام ہم تک پہنچ گیا ہے۔',
    'contact.form.sentBody': 'ہم {email} پر ایک کاروباری دن کے اندر جواب دے دیتے ہیں۔',
    'contact.form.sentUrgent': 'اگر معاملہ فوری ہے تو براہِ کرم ہمیں کال کریں:',
    'contact.form.sendAnother': 'ایک اور پیغام بھیجیں',
    'contact.needMore': 'براہِ کرم تھوڑا اور بتائیں — کم از کم ایک جملہ۔',
    'contact.tooSoon': 'یہ پیغام ہمیں پہلے ہی مل چکا ہے — ہم جلد جواب دیں گے۔',
    'contact.notSaved': 'ہم آپ کا پیغام محفوظ نہیں کر سکے۔ براہِ کرم کلینک کو کال کریں۔',
    'info.homeTitle': 'امراض، علاج اور عام سوالات',
    'info.homeSub': 'ہماری ویب سائٹ پر اپنے علاج کے بارے میں پڑھیں',
    'info.title': 'مزید جانیں',
    'info.lede':
        'جن امراض کا ہم علاج کرتے ہیں، ہمارے علاج، اور ملاقات کیسی ہوتی ہے — سب کے بارے میں پڑھیں۔ یہ صفحات کلینک کی ویب سائٹ پر کھلتے ہیں۔',
    'info.urduNote':
        'یہ صفحات اردو میں پڑھنے کے لیے ویب سائٹ پر ایک بار «اردو» منتخب کر لیں — ویب سائٹ آپ کی پسند یاد رکھے گی۔',
    'info.conditions': 'امراض',
    'info.conditionsSub': 'ڈپریشن، اینگزائٹی، او سی ڈی، بالوں کا گرنا، مہاسوں کے نشان اور بہت کچھ',
    'info.treatments': 'علاج',
    'info.treatmentsSub': 'نفسیاتی علاج، کیٹامین تھراپی، بوٹوکس، فلرز، پی آر پی',
    'info.telemedicine': 'ٹیلی میڈیسن',
    'info.telemedicineSub': 'آن لائن مشاورت کیسے ہوتی ہے',
    'info.whatToExpect': 'کیا توقع رکھیں',
    'info.whatToExpectSub': 'آپ کی پہلی ملاقات، قدم بہ قدم',
    'info.faq': 'عام سوالات',
    'info.faqSub': 'فیس، اوقات، رازداری اور مزید',
    'info.about': 'ہمارے بارے میں',
    'info.aboutSub': 'ہم کون ہیں اور کیسے کام کرتے ہیں',
    'info.blog': 'مضامین',
    'info.blogSub': 'ہمارے ڈاکٹروں کی تحریریں',
    'info.stillQuestions': 'اب بھی کوئی سوال ہے؟',

    'lang.english': 'English',
    'lang.urdu': 'اردو',
  };
}

/// Which language the app is in, remembered between launches.
///
/// The website keeps this in localStorage; the app keeps it in
/// SharedPreferences, and reads it before the first frame so an Urdu reader
/// never sees a flash of English on launch.
class LocaleController extends ChangeNotifier {
  LocaleController(this._isUrdu) {
    _current = this;
  }

  static const _key = 'locale.isUrdu';

  bool _isUrdu;

  /// The controller the app is actually running with.
  ///
  /// ── Why a global, when everything else takes a BuildContext ──
  ///
  /// Because plenty of the words a patient reads are not written by a widget.
  /// The API client turns a dropped connection into a sentence; the session
  /// window turns a time into "Starts in 20 min"; `errorText` turns anything
  /// thrown into something a person can act on. None of those has a context to
  /// reach the dictionary through, so every one of them had its English
  /// hard-coded — which is how an app can be fully translated and still show
  /// English the moment something goes wrong. And something going wrong is
  /// exactly when a patient most needs to be able to read the screen.
  ///
  /// Set from the constructor, so it exists before the first frame. There is
  /// only ever one of these: main() builds it and hands the same instance to
  /// the provider tree.
  static LocaleController? _current;

  /// Translates from outside the widget tree. Falls back to the key's English
  /// before the controller exists, which only happens in tests.
  static String tr(String key) {
    final controller = _current;
    if (controller != null) return controller.t(key);
    return Strings.en[key] ?? key;
  }

  /// True when the app is in Urdu, readable from anywhere.
  static bool get urdu => _current?._isUrdu ?? false;

  /// Read before the first frame, in main(). Awaiting it there rather than
  /// inside a widget is the whole point: a FutureBuilder would build one frame
  /// in English before the saved answer arrived, and that flash is exactly
  /// what this is meant to prevent.
  ///
  /// A failed read is not an error worth showing anyone — SharedPreferences
  /// can fail on a device with no writable storage, and English is a fine
  /// answer in that case.
  static Future<LocaleController> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return LocaleController(prefs.getBool(_key) ?? false);
    } catch (error) {
      debugPrint('[LocaleController] could not read saved language: $error');
      return LocaleController(false);
    }
  }

  bool get isUrdu => _isUrdu;
  Locale get locale => _isUrdu ? const Locale('ur') : const Locale('en');
  TextDirection get direction => _isUrdu ? TextDirection.rtl : TextDirection.ltr;

  /// Notifies first and writes afterwards. The switch should feel instant;
  /// remembering it is housekeeping and must never be in front of the UI.
  void set(bool urdu) {
    if (_isUrdu == urdu) return;
    _isUrdu = urdu;
    notifyListeners();
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setBool(_key, urdu))
        .catchError((Object error) {
      debugPrint('[LocaleController] could not save language: $error');
      return false;
    });
  }

  void toggle() => set(!_isUrdu);

  /// Urdu → English → the key itself, so nothing ever renders blank.
  String t(String key) {
    if (_isUrdu) {
      final value = Strings.ur[key];
      if (value != null) return value;
    }
    return Strings.en[key] ?? key;
  }

  /// The wording for an appointment status, or the raw status when the server
  /// invents a new one before the app has learned about it.
  String status(String raw) {
    final key = 'appt.status.\$raw';
    final value = t(key);
    return value == key ? raw : value;
  }

  /// The same status, worded for whoever is looking at it.
  ///
  /// "Waiting for your payment" is written to a patient. On a doctor's or an
  /// admin's screen it is simply wrong — it is not their payment — and on a
  /// busy schedule it also reads as something they are supposed to do. Where a
  /// staff wording exists it wins; everything else falls through unchanged, so
  /// adding one is a single key and no code.
  String statusFor(String raw, {required bool staff}) {
    if (staff) {
      final staffKey = 'appt.statusStaff.\$raw';
      final staffValue = t(staffKey);
      if (staffValue != staffKey) return staffValue;
    }
    return status(raw);
  }
}
