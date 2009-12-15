/**
 *  Copyright (c)  2009 coltware.com
 *  http://www.coltware.com 
 *
 *  License: LGPL v3 ( http://www.gnu.org/licenses/lgpl-3.0-standalone.html )
 *
 * @author coltware@gmail.com
 */
package com.coltware.airxmail.MailSender
{
	import com.coltware.airxmail.IMailSender;
	import com.coltware.airxmail.MimeMessage;
	import com.coltware.airxmail.smtp.SMTPClient;
	import com.coltware.airxmail.smtp.SMTPEvent;
	import com.coltware.airxmail_internal;
	
	import flash.events.EventDispatcher;
	import flash.utils.IDataOutput;
	import flash.utils.getDefinitionByName;
	
	import mx.logging.ILogger;
	import mx.logging.Log;
	
	use namespace airxmail_internal;
	
	/**
	 *  MimeMessageオブジェクトからSMTPでメールを送信するためのクラス
	 * 
	 */
	public class SMTPSender extends EventDispatcher implements IMailSender
	{
		private static var log:ILogger = Log.getLogger("com.coltware.airxmail.MailSender.SMTPSender");
		
		private var client:SMTPClient;
		private var currentMessage:MimeMessage;
		
		private var TLS_CLASSNAME:String ="com.hurlant.crypto.tls.TLSSocket";
		
		private var _smtpAuth:Boolean = false;
		private var _userName:String = null;
		private var _userPswd:String = null;
		
		/**
		 * HELOするときのホスト名
		 */
		private var _myhost:String = "localhost";
		
		public function SMTPSender() 
		{
			client = new SMTPClient();
			client.addEventListener(SMTPEvent.SMTP_ACCEPT_DATA,writeData);
			client.addEventListener(SMTPEvent.SMTP_CONNECTION_FAILED,fireConnectionFailed);
		}
		
		/**
		 *  Senderに依存したパラメータの値を指定する.
		 * 
		 * <pre>
		 * host 		:  接続するSMTPのホスト名 or IP
		 * port 		:  接続するSMTPのポート番号
		 * myhostname	:  SMTPで接続する際にHELO(EHLO) myhostname となる部分。デフォルトはlocalhost
		 * </pre>
		 */
		public function setParameter(key:String,value:Object):void{
			key = key.toLowerCase();
			var vstr:String;
			var vbool:Boolean;
			log.debug("set param " + key + " => " + value);
			switch(key){
				case "host":
					client.host = String(value); 
					break;
				case "port":
					client.port = parseInt(String(value));
					break;
				case "auth":
					vstr = value as String;
					vbool = value as Boolean;
					if(vbool || ( vstr && vstr.toLowerCase() == "true")){
						this._smtpAuth = true;
					}
					break;
				case "username":
					vstr = value as String;
					if(vstr){
						this._userName = vstr;
					}
					break;
				case "password":
					vstr = value as String;
					if(vstr){
						this._userPswd = vstr;
					}
					break;
				case "ssl":
					vstr = value as String;
					vbool = value as Boolean;
					if(vbool || ( vstr && vstr.toLowerCase() == "true")){
						var tlsClz:Class = getDefinitionByName(TLS_CLASSNAME) as Class;
						var tlsObj:Object = new tlsClz();
						client.socketObject = obj;
					}
					break;
				case "socket":
					if(value is String){
						var clz:Class = getDefinitionByName(String(value)) as Class;
						var obj:Object = new clz();
						client.socketObject = obj;
					}
					else{
						log.info("set socket object " + value);
						client.socketObject = value;
					}
					break;
				case "myhostname":
					this._myhost = String(value);
					break;
			}
		}
		/**
		 * メールを送信する.
		 * 
		 * 大量に送信することは想定されておらず、１回１回、接続をする
		 * 
		 */ 
		public function send(message:MimeMessage, ... args):void{
			log.info("[start] msg send"); 
			this.currentMessage = message;
			if(!client.isConnected){
				log.debug("connect ... ");
				client.connect();
				client.ehlo(this._myhost);
			}
			var i:int;
			
			//  認証が必要ならする
			if(_smtpAuth){
				client.setAuth(_userName,_userPswd);
			}
			
			//  MAIL FROM:
			var envelopFrom:String = message.fromInetAddress.address;
			if(args[0] && args[0] is String){
				envelopFrom = args[0];
			}
			client.mailFrom(envelopFrom);
			
			var len:int = 0;
			//  TOを設定する
			var rcpts:Array = message.$toRcpts.concat(message.$ccRcpts,message.$bccRcpts);
			len = rcpts.length;
			for(i=0; i<len; i++){
				client.rcptTo(rcpts[i].address);
			}
			client.dataAsync();
			
		}
		
		/**
		 *   データを書き込む
		 */
		private function writeData(e:SMTPEvent):void{
			var sock:Object = e.$sock;
			this.currentMessage.writeHeaderSource(IDataOutput(sock));
			sock.writeUTFBytes("\r\n");
			sock.flush();
			this.currentMessage.writeBodySource(IDataOutput(sock));
			sock.writeUTFBytes("\r\n.\r\n");
			sock.flush();
			client.quit();
		}
		
		/**
		 * @private
		 */
		protected function fireConnectionFailed(e:* = null):void{
			//  サービスの準備ができないまま、サーバからの切断なので
			var event:SMTPEvent = new SMTPEvent(SMTPEvent.SMTP_CONNECTION_FAILED,true);
			this.dispatchEvent(event);
		}
		
		
		

	}
}