/**
 *  Copyright (c)  2009 coltware.com
 *  http://www.coltware.com 
 *
 *  License: LGPL v3 ( http://www.gnu.org/licenses/lgpl-3.0-standalone.html )
 *
 * @author coltware@gmail.com
 */
package com.coltware.airxmail.pop3
{
	import com.coltware.airxmail.MailParser;
	import com.coltware.commons.job.SocketJobSync;
	import com.coltware.commons.utils.StringLineReader;
	
	import flash.events.IEventDispatcher;
	import flash.events.ProgressEvent;
	import flash.utils.ByteArray;
	import flash.utils.IDataInput;
	
	import mx.logging.ILogger;
	import mx.logging.Log;
	import mx.utils.StringUtil;
	import mx.utils.UIDUtil;
	
	[Event(name="jobStackEmpty",type="com.coltware.commons.job.JobEvent")]
	[Event(name="jobIdleTimeout",type="com.coltware.commons.job.JobEvent")]
	
	[Event(name="pop3ResultStat",type="com.coltware.airxmail.pop3.POP3Event")]
	[Event(name="pop3ResultList",type="com.coltware.airxmail.pop3.POP3Event")]
	[Event(name="pop3ResultUidl",type="com.coltware.airxmail.pop3.POP3Event")]
	[Event(name="pop3ResultRetr",type="com.coltware.airxmail.pop3.POP3Event")]
	[Event(name="pop3DeleteOk",type="com.coltware.airxmail.pop3.POP3Event")]
	[Event(name="pop3NoopOk",type="com.coltware.airxmail.pop3.POP3Event")]
	
	/**
	 *  POP3 Auth OK
	 * 
	 * @eventType com.coltware.airxmail.pop3.POP3Event.POP3_AUTH_OK;
	 */
	[Event(name="pop3AuthOk",type="com.coltware.airxmail.pop3.POP3Event")]
	/**
	 *  POP3 Auth NG
	 * 
	 * @eventType com.coltware.airxmail.pop3.POP3Event.POP3_AUTH_NG;
	 */
	[Event(name="pop3AuthNg",type="com.coltware.airxmail.pop3.POP3Event")]

	public class POP3Client extends SocketJobSync
	{
		private static var log:ILogger = Log.getLogger("com.coltware.airxmail.pop3.POP3Client");
		
		private var _lineReader:StringLineReader;
		private var _parser:MailParser;
		
		private var _clientId:String;
		
		/**
		 * POP3におけるuserコマンド
		 */
		private const DO_USER:String = "USER";
		/**
		 * POP3におけるpassコマンド
		 */
		private const DO_PASS:String = "PASS";
		private const DO_UIDL:String = "UIDL";
		private const DO_STAT:String = "STAT";
		private const DO_LIST:String = "LIST";
		private const DO_RETR:String = "RETR";
		private const DO_QUIT:String = "QUIT";
		private const DO_DELE:String = "DELE";
		private const DO_NOOP:String = "NOOP";
		
		/**
		 *  POPのUIDと番号を結ぶマップ
		 *  UIDLコマンドの結果で値が埋められる
		 */
		private var _uidMap:Object;
		
		private var _sizeMap:Object;
		
		private var _octets:int = 0;
		
		public function POP3Client(target:IEventDispatcher=null)
		{
			super(target);
			_lineReader = new StringLineReader();
			_parser = new MailParser();
			this.port = 110;
			this._uidMap = new Object();
			this._sizeMap = new Object();
			this._clientId = UIDUtil.createUID();
		}
		
		public function connectAuth(user:String,pswd:String):void{
			this.connect();
			var job1:Object = new Object();
			job1.key = DO_USER;
			job1.value = user;
			this.addJob(job1);
			
			var job2:Object = new Object();
			job2.key = DO_PASS;
			job2.value = pswd;
			this.addJob(job2);
		}
		/**
		 * このオブジェクトを識別するID
		 */
		public function get clientId():String{
			return this._clientId;
		}
		public function set clientId(n:String):void{
			this._clientId = n;
		}
		
		public function stat():void{
			var job:Object = new Object();
			job.key = DO_STAT;
			job.value = "";
			this.addJob(job);
		}
		public function noop():void{
			var job:Object = new Object();
			job.key = DO_NOOP;
			job.value = "";
			this.addJob(job);
		}
		
		public function uidl():void{
			var job:Object = new Object();
			job.key = DO_UIDL;
			job.value = "";
			this.addJob(job);
		}
		
		public function retr(i:int, uid:String = null):void{
			var job:Object = new Object();
			job.key = DO_RETR;
			job.value = String(i);
			job.uid = uid;
			this.addJob(job);
		}
		public function dele(i:int):void{
			var job:Object = new Object();
			job.key = DO_DELE;
			job.value = i;
			this.addJob(job);
		}
		/**
		 *  UIDから番号を取得する
		 */
		public function getNumberByUid(uid:String):String{
			if(this._uidMap[uid]){
				return this._uidMap[uid];
			}
			else{
				return "";
			}
		}
		/**
		 *  番号からUIDを取得する
		 * 
		 * メモ：この処理を投げる前に必ず uidl() 処理が実行されている必要があります。
		 */
		public function getUidByNumber(num:int):String{
			for(var uid:String in this._uidMap){
				if(this._uidMap[uid] == num){
					return uid;
				}
			}
			return "";
		}
		
		public function list():void{
			var job:Object = new Object();
			job.key = DO_LIST;
			job.value = "";
			this.addJob(job);
			
		}
		
		public function quit():void{
			var job:Object = new Object();
			job.key = DO_QUIT;
			job.value = "";
			this.addJob(job);
		}
		
		override protected function exec(job:Object):void{
			var cmd:String = "";
			if(job.value){
				cmd = job.key + " " + job.value;
			}
			else{
				cmd = job.key;
			}
			log.debug("CMD>" + cmd);  
			this._sock.writeUTFBytes(cmd +"\r\n");
			this._sock.flush();
			this._octets = 0;
		}
		
		override protected function handleData(pe:ProgressEvent):void{
			var errEvt:POP3Event;
			_lineReader.source = IDataInput(_sock);
			var line:String = null;
			if(this.isServiceReady){
				var job:Object = this.currentJob;
				if(job == null){
					log.warn("handleData [job is null]" + pe);
					return;
				}
				var cmd:String = job.key;
				if(cmd == DO_USER || cmd == DO_PASS){
					line = _lineReader.next();
					log.debug(cmd + ">" + line);
					if(line.substr(0,3) == "+OK"){
						this.commitJob();
						if(cmd == DO_PASS){
							//  AUTH OK
							var authOkEvent:POP3Event = new POP3Event(POP3Event.POP3_AUTH_OK);
							authOkEvent.client = this;
							this.dispatchEvent(authOkEvent);
						}
					}
					else{
						// @TODO 認証に失敗したときのエラーを投げる
						var authNgEvent:POP3Event = new POP3Event(POP3Event.POP3_AUTH_NG);
						authNgEvent.client = this;
						this.dispatchEvent(authNgEvent);
					}
				}
				else if(cmd == DO_STAT){
					line = _lineReader.next();
					if(line.substr(0,3) == "+OK"){
						var msg:String = line.substr(4);
						
						this.commitJob();
						var arr:Array = msg.split(" ");
						var statEvent:POP3Event = new POP3Event(POP3Event.POP3_RESULT_STAT);
						statEvent.client = this;
						statEvent.result = new Object();
						statEvent.result.total = arr[0];
						statEvent.result.size = arr[1];
						this.dispatchEvent(statEvent);
					}
					else{
						//  @TODO 
						errEvt = new POP3Event(POP3Event.POP3_COMMAND_ERROR);
						errEvt.message = line;
						this.dispatchEvent(errEvt);
						this.commitJob();
					}
				}
				else if(cmd == DO_DELE){
					line = _lineReader.next();
					if(line.substr(0,3) == "+OK"){
						var deleEvent:POP3Event = new POP3Event(POP3Event.POP3_DELETE_OK);
						deleEvent.result = job.value;
						this.dispatchEvent(deleEvent);
						this.commitJob();
					}
					else{
						errEvt = new POP3Event(POP3Event.POP3_COMMAND_ERROR);
						errEvt.message = line;
						this.dispatchEvent(errEvt);
						this.commitJob();
					}
				}
				else if(cmd == DO_LIST || cmd == DO_UIDL ){
					
					while(line = _lineReader.next()){
						line = StringUtil.trim(line);
						if(job.result){
							if(line == "."){
								var listEvent:POP3Event;
								if(cmd == DO_LIST){
									listEvent = new POP3Event(POP3Event.POP3_RESULT_LIST);	
								}
								else{
									listEvent = new POP3Event(POP3Event.POP3_RESULT_UIDL);
								}
								listEvent.client = this;
								listEvent.result = job.data;
								this.dispatchEvent(listEvent);
								this.commitJob();
							}
							else{
								var p:Array = line.split(/[[:space:]]+/);
								if(cmd == DO_UIDL){
									var obj:POP3UID = new POP3UID();
									obj.number = int(p[0]);
									obj.value  = p[1];
									job.data.push(obj);
									this._uidMap[obj.value] = obj.number;
								}
								else{
									var size:Object = new Object();
									size.number = int(p[0]);
									size.value  = int(p[1]);
									job.data.push(size);
									this._sizeMap[size.number] = size.value;
								}
							}
						}
						else{
							if(line.substr(0,3) == "+OK"){
								job.result = true;
								job.data = new Array();
							}
							else if(line.substr(0,4) == "+ERR"){
								//  ERROR
								var errEvent:POP3Event = new POP3Event(POP3Event.POP3_COMMAND_ERROR);
								errEvent.client = this;
								errEvent.message = line;
								this.dispatchEvent(errEvent);
							}
						}
					}
				}
				else if(cmd == DO_RETR){
					var l:String;
					var next:Boolean = true;
					
					while(line = _lineReader.next()){
						if(job.status == null){
							log.info("[RETR]" + line);
							l = StringUtil.trim(line);
							if(l.substr(0,3) == "+OK"){
								job.status = true;
								var _uid:String = job.uid;
								if(_uid == null){
									_uid = this.getUidByNumber(int(job.value));
								}
								_parser.parseStart(_uid);
								job.source = new ByteArray();
							}
						}
						else{
							var buf:ByteArray = job.source as ByteArray;
							buf.writeBytes(_lineReader.lastBytearray());
							l = StringUtil.trim(line);
							if(l == "."){
								//  BODYの終了
								var bodyEvent:POP3MessageEvent = new POP3MessageEvent(POP3MessageEvent.POP3_MESSAGE);
								bodyEvent.client = this;
								bodyEvent.result = _parser.parseEnd();
								bodyEvent.octets = this._sizeMap[job.value];
								bodyEvent.source = job.source;
								this.dispatchEvent(bodyEvent);
								this.commitJob();
							}
							else{
								_parser.parseLine(line,_lineReader);
							} 
						}
						
					}
				}
			}
			else{
				this.handleNotServiceReady(_lineReader);
			}
		}
		/**
		 *   サービスがまだ準備できていない時の処理
		 * 
		 */
		private function handleNotServiceReady(reader:StringLineReader):void{
			var line:String;
			while(line = _lineReader.next()){
				log.debug("[NO] " + line);
				if(line.substr(0,3) == "+OK"){
					this.serviceReady();
					break;
				}
			}
			var e:POP3Event;
			if(this.isServiceReady){
				e = new POP3Event(POP3Event.POP3_CONNECT_OK);
			}
			else{
				e = new POP3Event(POP3Event.POP3_CONNECT_NG);
			}
			e.client = this;
			this.dispatchEvent(e);
		}
		/*
		private function createMimeMessage(headers:Array):void{
			
		}
		*/
	}
}