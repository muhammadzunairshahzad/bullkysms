<?php
	$Path = "../";
	include("api_include.php");

	// Counters — declared before the first goto so the Response block can always
	// read them, even when we jump straight there from a failed login.
	$Saved       = 0;
	$Duplicate   = 0;
	$Rejected    = 0;
	$RejectedIDs = array();

	$objRow = VerifyLogin();
	if (is_array($objRow))
	{
		$RespHead = $objRow[0];
		$RespText = $objRow[1];
		goto Response;
	}

	$ClientMobID = isset($Json->ClientMobID) ? trim(strval($Json->ClientMobID)) : "";
	$ClientID    = isset($Json->ClientID)    ? strval($Json->ClientID)          : "";
	$DeviceName  = isset($Json->DeviceName)  ? strval($Json->DeviceName)        : "";

	// ClientMobID is half of the unique key. If it were ever blank the key would
	// collapse to ('', eventid), shared across every device — and because eventid
	// is content-derived, two handsets receiving the same broadcast SMS would then
	// suppress each other's row. Refuse rather than corrupt.
	if ($ClientMobID == "")
	{
		$RespHead = "Error";
		$RespText = "Malformed Json - ClientMobID Missing";
		goto Response;
	}

	// DeviceName column is VARCHAR(100); the app sends "<name>-<mobile>".
	$DeviceName = substr($DeviceName, 0, 100);

	$CountryCode = GetClientCountryCode($ClientID);
	$MobUtil     = \libphonenumber\PhoneNumberUtil::getInstance();

	// ── Detail array ────────────────────────────────────────────────────────────
	// Expected shape:
	//   "Detail": [
	//     { "EventID": "...", "Mobile": "03001234567",
	//       "Message": "text", "SMSDate": "2026-08-27 10:00:00+05:00" },
	//     ...
	//   ]
	// A single message is just an array of one — no special case needed.

	if (isset($Json->Detail) == false)
	{
		$RespHead = "Error";
		$RespText = "Malformed Json - Detail Array Missing";
		goto Response;
	}

	$Detail = $Json->Detail;

	// Tolerate a lone object being sent instead of an array of one.
	if (is_object($Detail))
	{
		$Detail = array($Detail);
	}

	if (is_array($Detail) == false)
	{
		$RespHead = "Error";
		$RespText = "Malformed Json - Detail Must Be An Array";
		goto Response;
	}

	// An empty batch is a no-op, not an error. Returning success lets the app
	// clear its queue instead of retrying forever.
	if (count($Detail) == 0)
	{
		$RespHead = "ReceivedSMS";
		$RespText = "Done";
		goto Response;
	}

	// ── Prepared statement ──────────────────────────────────────────────────────
	// INSERT IGNORE + the UNIQUE (clientmobid, eventid) index makes this endpoint
	// idempotent: the app retries a batch up to 3 times, and a retry after a
	// successful insert whose response was lost now silently no-ops instead of
	// creating a duplicate row.
	//
	// Every mysqli call below is wrapped, because PHP 8.1+ defaults mysqli to
	// MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT — it THROWS rather than returning
	// false. Unguarded, that turns any one bad row into a 500 for the whole
	// request, and since the app only ever posts the batch as a unit, that row
	// becomes a poison pill that blocks the inbound queue permanently.

	$Sql = "INSERT IGNORE INTO smsreclist".
		" (clientmobid, eventid, smsdate, mobile, smstext, devicename)".
		" VALUES (?, ?, ?, ?, ?, ?)";

	try
	{
		$Stmt = mysqli_prepare($Conn, $Sql);
	}
	catch (\mysqli_sql_exception $e)
	{
		$Stmt = false;
		error_log("sms_received -> prepare threw\n".$Sql."\n".$e->getMessage());
	}

	if ($Stmt == false)
	{
		error_log("sms_received -> prepare failed\n".$Sql."\n".mysqli_error($Conn));
		$RespHead = "Error";
		$RespText = "Server Error - Unable To Save Messages";
		goto Response;
	}

	try
	{
		mysqli_begin_transaction($Conn);
	}
	catch (\mysqli_sql_exception $e)
	{
		mysqli_stmt_close($Stmt);
		error_log("sms_received -> begin_transaction threw\n".$e->getMessage());
		$RespHead = "Error";
		$RespText = "Server Error - Unable To Save Messages";
		goto Response;
	}

	foreach ($Detail as $Item)
	{
		if (is_object($Item) == false && is_array($Item) == false)
		{
			$Rejected++;
			continue;
		}
		$Item = (object)$Item;

		$MobileNo = isset($Item->Mobile)  ? trim(strval($Item->Mobile))  : "";
		$Message  = isset($Item->Message) ? strval($Item->Message)       : "";
		$SmsDate  = isset($Item->SMSDate) ? trim(strval($Item->SMSDate)) : "";
		$EventID  = isset($Item->EventID) ? trim(strval($Item->EventID)) : "";

		if ($MobileNo == "")
		{
			$Rejected++;
			$RejectedIDs[] = $EventID;
			continue;
		}

		// Strip the separators humans and handsets add.
		$MobileNo = str_replace(array("-", " ", "(", ")", "."), "", $MobileNo);

		// Normalise to E164 where the number is parseable. parse() throws on junk
		// input and on a missing/invalid default region, so it must be guarded —
		// an uncaught NumberParseException here would fail the whole batch rather
		// than the one bad row.
		if (preg_match("/[0-9]/", $MobileNo) == 1)
		{
			try
			{
				$Mobile = $MobUtil->parse($MobileNo, $CountryCode);
				if ($MobUtil->isValidNumber($Mobile) == true)
				{
					$MobileNo = $MobUtil->format($Mobile, \libphonenumber\PhoneNumberFormat::E164);
				}
			}
			catch (\libphonenumber\NumberParseException $e)
			{
				// Unparseable — fall through to the gate below, which still lets
				// through shortcodes and alphanumeric sender IDs.
			}
		}

		// Two legitimate shapes reach this point: a real number (now E164 where it
		// could be parsed) and an alphanumeric sender ID. Banks, OTP services and
		// marketing shortcodes all reply from things like "VODAFONE" or "PRIMEMED",
		// and a numeric-only gate silently dropped every one of them — which for an
		// endpoint whose entire job is capturing inbound replies is the wrong
		// tradeoff. Accept both; reject only what cannot be stored.
		$IsNumber   = preg_match("/^[\+]?[0-9]{3,20}$/", $MobileNo) == 1;
		$IsSenderID = preg_match("/^[A-Za-z0-9][A-Za-z0-9_]{1,19}$/", $MobileNo) == 1;

		if ($IsNumber == false && $IsSenderID == false)
		{
			$Rejected++;
			$RejectedIDs[] = $EventID;
			continue;
		}

		$SmsDate = NormaliseSmsDate($SmsDate);

		// Hash rather than truncate when the client key is wider than the column.
		//
		// substr($EventID, 0, 64) here was actively harmful: the app's key is
		// "fallback_<mobile>_<message>_<bucket>", so cutting at 64 discarded the
		// bucket — the only part making it unique — along with most of the message.
		// Two different texts from the same number sharing a ~42 character prefix
		// then produced an identical eventid and INSERT IGNORE dropped the second
		// one permanently. sha1 keeps the full entropy in 40 characters.
		if ($EventID == "")
		{
			$EventID = sha1($ClientMobID."|".$MobileNo."|".$Message."|".$SmsDate);
		}
		elseif (strlen($EventID) > 64)
		{
			$EventID = sha1($EventID);
		}

		$Ok = false;
		try
		{
			mysqli_stmt_bind_param(
				$Stmt, "ssssss",
				$ClientMobID, $EventID, $SmsDate, $MobileNo, $Message, $DeviceName
			);
			$Ok = mysqli_stmt_execute($Stmt);
		}
		catch (\mysqli_sql_exception $e)
		{
			error_log("sms_received -> insert threw for ".$MobileNo."\n".$e->getMessage());
		}

		if ($Ok == false)
		{
			$ErrNo = mysqli_errno($Conn);

			// 1213 deadlock, 1205 lock wait timeout. MySQL rolls back the ENTIRE
			// transaction for both, so everything already counted in $Saved is
			// already gone. Carrying on would commit only the tail while still
			// reporting success, and the app would delete the rest. Fail the whole
			// batch instead and let the app retry — safe now that
			// (clientmobid, eventid) makes a repeat POST a no-op.
			if ($ErrNo == 1213 || $ErrNo == 1205)
			{
				mysqli_stmt_close($Stmt);
				mysqli_rollback($Conn);
				error_log("sms_received -> rolled back batch, mysql errno ".$ErrNo);
				$Saved       = 0;
				$Duplicate   = 0;
				$Rejected    = 0;
				$RejectedIDs = array();
				$RespHead    = "Error";
				$RespText    = "Server Busy - Please Retry";
				goto Response;
			}

			error_log("sms_received -> insert failed for ".$MobileNo."\n".mysqli_stmt_error($Stmt));
			$Rejected++;
			$RejectedIDs[] = $EventID;
			continue;
		}

		// INSERT IGNORE reports 1 affected row on insert, 0 when the unique index
		// suppressed a duplicate.
		if (mysqli_stmt_affected_rows($Stmt) > 0)
		{
			$Saved++;
		}
		else
		{
			$Duplicate++;
		}
	}

	mysqli_stmt_close($Stmt);

	$Committed = false;
	try
	{
		$Committed = mysqli_commit($Conn);
	}
	catch (\mysqli_sql_exception $e)
	{
		error_log("sms_received -> commit threw\n".$e->getMessage());
	}

	// Without this check a failed commit still answered "Done", the app marked
	// every event as sent and deleted it from both memory and disk — total silent
	// loss of the batch with nothing written.
	if ($Committed == false)
	{
		error_log("sms_received -> commit failed\n".mysqli_error($Conn));
		$Saved       = 0;
		$Duplicate   = 0;
		$Rejected    = 0;
		$RejectedIDs = array();
		$RespHead    = "Error";
		$RespText    = "Server Error - Commit Failed";
		goto Response;
	}

	if ($Rejected > 0)
	{
		error_log(
			"sms_received -> ClientMobID ".$ClientMobID.
			": saved ".$Saved.", duplicate ".$Duplicate.", rejected ".$Rejected
		);
	}

	$RespHead = "ReceivedSMS";
	$RespText = "Done";

	// ── Response ────────────────────────────────────────────────────────────────
	Response:

	$Response = SendJsonResponse($RespHead, $RespText);

	// SendJsonResponse is expected to return the encoded body. Coerce defensively:
	// json_decode() on a non-string is a TypeError in PHP 8, and @ does not
	// suppress those.
	if (is_string($Response) == false)
	{
		$Response = json_encode($Response);
	}

	// Attach per-batch counts without touching the shared SendJsonResponse helper.
	// DocType and Message are left exactly as they were, so the app's existing
	// success check keeps working; the counts are purely additive.
	if ($RespHead == "ReceivedSMS")
	{
		$RespObj = json_decode($Response);
		if (is_object($RespObj))
		{
			$RespObj->Saved     = $Saved;
			$RespObj->Duplicate = $Duplicate;
			$RespObj->Rejected  = $Rejected;

			// The app deletes the whole batch on "Done", so a row we threw away is
			// gone for good. Naming the keys at least makes that loss visible and
			// traceable in the device log instead of silent.
			$RespObj->RejectedIDs = $RejectedIDs;

			$Response = json_encode($RespObj);
		}
	}

	echo($Response);

	// ── Helpers ─────────────────────────────────────────────────────────────────

	/**
	 * Coerces whatever the client sent into a MySQL DATETIME string.
	 *
	 * Handles '2026-08-27 10:00:00', the same with a '+05:00' offset (which is
	 * what the app now sends), ISO 8601 with a 'T' separator, trailing fractional
	 * seconds, and a trailing 'Z'. Falls back to the current server time rather
	 * than letting an unparseable value reach the column, where MySQL would
	 * silently store '0000-00-00 00:00:00'.
	 *
	 * date() renders in the server's timezone, so an offset-bearing input is
	 * converted correctly and stays consistent with every other timestamp in the
	 * database. A value with NO offset is assumed to already be server-local.
	 */
	function NormaliseSmsDate($Value)
	{
		$Value = trim(strval($Value));
		if ($Value != "")
		{
			$Time = strtotime($Value);
			if ($Time !== false && $Time > 0)
			{
				return date("Y-m-d H:i:s", $Time);
			}
		}
		return date("Y-m-d H:i:s");
	}
?>
