/**
 *  Copyright (c)  2009 coltware.com
 *  http://www.coltware.com 
 *
 *  License: LGPL v3 ( http://www.gnu.org/licenses/lgpl-3.0-standalone.html )
 *
 * @author coltware@gmail.com
 */
package com.coltware.airxmail.imap
{
	import com.coltware.airxmail.IMessageEvent;
	import com.coltware.airxmail.MimeMessage;
	
	import flash.utils.ByteArray;
	
	public class IMAP4MessageEvent extends IMAP4Event implements IMessageEvent
	{
		public static const IMAP4_MESSAGE:String = "imap4Message";
		
		public var octets:int = 0;
		public var source:ByteArray;
		
		public function IMAP4MessageEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false)
		{
			super(type, bubbles, cancelable);
		}
		
		public function getMimeMessage():MimeMessage
		{
			var msg:MimeMessage = _result as MimeMessage;
			return msg;
		}
	}
}