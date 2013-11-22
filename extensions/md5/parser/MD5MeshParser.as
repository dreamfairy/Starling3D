package starling.extensions.md5.parser
{
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.geom.Vector3D;
	import flash.utils.ByteArray;
	
	import starling.extensions.md5.model.IJoint;
	import starling.extensions.md5.model.MD5Joint;
	import starling.extensions.md5.model.MD5MeshData;
	import starling.extensions.md5.model.MD5Triangle;
	import starling.extensions.md5.model.MD5Vertex;
	import starling.extensions.md5.model.MD5Weight;
	import starling.extensions.md5.model.Quaternion;

	public class MD5MeshParser extends EventDispatcher
	{
		public function MD5MeshParser()
		{
			_rotationQuat = new Quaternion();
			_rotationQuat.fromAxisAngle(Vector3D.X_AXIS, -Math.PI * .5);
		}
		
		public function load(data : ByteArray) : void
		{
			_textData = data.readUTFBytes(data.bytesAvailable);
			handleData();
		}
		
		private function handleData() : void
		{
			var token : String;
			while(true){
				token = getNextToken();
				switch(token)
				{
					case COMMENT_TOKEN:
						ignoreLine();
						break;
					case VERSION_TOKEN:
						_version = getNextInt();
						if(_version != 10) throw new Error("版本错误，支持的是10");
						break;
					case COMMAND_LINE_TOKEN:
						parseCMD();
						break;
					case NUM_JOINTS_TOKEN:
						num_joints = getNextInt();
						md5_joint = new Vector.<IJoint>();
						break;
					case NUM_MESHES_TOKEN:
						num_meshes = getNextInt();
//						md5_mesh = new MeshData();
						break;
					case JOINTS_TOKEN:
						parseJoints();
						break
					case MESH_TOKEN:
						parseMesh();
						break;
					default:
						if(!_reachedEOF)
							throw new Error("关键词错误");
				}
				
				if(_reachedEOF){
					calculateMaxJointCount();
					this.dispatchEvent(new Event(Event.COMPLETE));
					break;
				}
			}
		}
		
		/**
		 * 计算最大权重
		 */
		private function calculateMaxJointCount() : void
		{
			maxJointCount = 0;
			
			var numMeshData : int = md5_mesh.length;
			for(var i : int = 0; i < numMeshData; ++i)
			{
				var meshData : MD5MeshData = md5_mesh[i];
				var vertexData : Vector.<MD5Vertex> = meshData.md5_vertex;
				var numVerts : int = vertexData.length;
				
				for(var j : int = 0; j < numVerts; ++j)
				{
					var zeroWeights : int = countZeroWeightJoints(vertexData[j], meshData.md5_weight);
					var totalJoints : int = vertexData[j].weight_count - zeroWeights;  //总骨骼数不包含0权重的骨骼
					if(totalJoints > maxJointCount)
						maxJointCount = totalJoints;
				}
			}
		}
		
		/**
		 * 计算0权重关节数量
		 */
		private function countZeroWeightJoints(vertex : MD5Vertex, weights : Vector.<MD5Weight>) : int
		{
			var start : int = vertex.weight_index;
			var end : int = vertex.weight_index + vertex.weight_count;
			var count : int = 0;
			var weight : Number;
			
			for(var i : int = start; i < end; ++i){
				weight = weights[i].bias;
				if(weight == 0) {
//					++count;
					weights[i].bias = 0.0000001;
				}
			}
			
			return count;
		}
		
		/**
		 * 解析网格几何体
		 */
		private function parseMesh() : void
		{
			var token : String = getNextToken();
			var ch : String;
			
			if(token != "{") throw new Error("关键字错误");
			
			_shaders ||= new Vector.<String>();
			md5_mesh ||= new Vector.<MD5MeshData>();
			
			var mesh : MD5MeshData = new MD5MeshData();
			
			while(ch != "}") {
				ch = getNextToken();
				switch(ch){
					case COMMENT_TOKEN:
						ignoreLine();
						break;
					case MESH_SHADER_TOKEN:
						_shaders.push(parseLiteralString());
						break;
					case MESH_NUM_VERTS_TOKEN:
						mesh.num_verts = getNextInt();
						mesh.md5_vertex = new Vector.<MD5Vertex>();
						break;
					case MESH_NUM_TRIS_TOKEN:
						mesh.num_tris = getNextInt();
						mesh.md5_triangle = new Vector.<MD5Triangle>();
						break;
					case MESH_VERT_TOKEN:
						parseVertex(mesh.md5_vertex);
						break;
					case MESH_TRI_TOKEN:
						parseTri(mesh.md5_triangle);
						break;
					case MESH_WEIGHT_TOKEN:
						parseWeight(mesh.md5_weight)
						break;
				}
			}
			
			md5_mesh.push(mesh);
		}
		
		/**
		 * 从数据流中读取下一个关节权重
		 */
		private function parseWeight(weights : Vector.<MD5Weight>) : void
		{
			var weight : MD5Weight = new MD5Weight();
			weight.id = getNextInt();
			weight.jointID = getNextInt();
			weight.bias = getNextNumber();
			weight.pos = parseVector3D();
			weights.push(weight);
		}
		
		/**
		 * 从数据流中读取下一个三角形,并存入列表中
		 */
		private function parseTri(indices : Vector.<MD5Triangle>) : void
		{
			var tri : MD5Triangle = new MD5Triangle();
			tri.id = getNextInt();
			tri.indexVec = new Vector.<uint>();
			tri.indexVec.push(getNextInt());
			tri.indexVec.push(getNextInt());
			tri.indexVec.push(getNextInt());
			
			indices.push(tri);
		}
		
		/**
		 * 从数据流中取出下一个顶点,并存入列表中
		 */
		private function parseVertex(vertexData : Vector.<MD5Vertex>) : void
		{
			var vertex : MD5Vertex = new MD5Vertex();
			vertex.id = getNextInt();
			parseUV(vertex);
			vertex.weight_index = getNextInt();
			vertex.weight_count = getNextInt();
			
			vertexData.push(vertex);
		}
		
		/**
		 * 从数据流中读取uv坐标,并存入顶点数据中
		 */
		private function parseUV(vertexData : MD5Vertex) : void
		{
			var ch : String = getNextToken();
			if(ch != "(") throw new Error("解析错误，错误的(");
			vertexData.uv_x = getNextNumber();
			vertexData.uv_y = getNextNumber();
			
			if(getNextToken() != ")") throw new Error("解析错误，错误的)");
		}
		
		/**
		 * 解析关节
		 */
		private function parseJoints() : void
		{
			var ch : String;
			var i : int = 0;
			var token : String = getNextToken();
			var joint : MD5Joint;
			
			if(token != "{") throw new Error("关键字错误");
			do{
				if(_reachedEOF) throw new Error("到达文件尾");
				
				joint = new MD5Joint();
				joint.name = parseLiteralString();
				joint.parentIndex = getNextInt();
				var pos : Vector3D = parseVector3D();
//				pos = _rotationQuat.rotatePoint(pos);
				var quat : Quaternion = parseQuaternion();
				joint.bindPose = quat.toMatrix3D();
				joint.bindPose.appendTranslation(pos.x,pos.y,pos.z);
				joint.inverseBindPose = joint.bindPose.clone();
				joint.inverseBindPose.invert();
				
//				var m1 : Matrix3D = joint.bindPose;
//				var m2 : Matrix3D = joint.inverseBindPose;
//				
//				m1.append(m2);
//				m2.transpose();
				
				md5_joint.push(joint);
				
				ch = getNextChar();
				
				if(ch == "/"){
					putBack();
					ch = getNextToken();
					if(ch == COMMENT_TOKEN) ignoreLine();
					ch = getNextChar();
				}
				if(ch != "}") putBack();
			}while(ch != "}");
		}
		
		/**
		 * 从数据流中解析下一个四元数
		 */
		private function parseQuaternion() : Quaternion
		{
			var quat : Quaternion = new Quaternion();
			var ch : String = getNextToken();
			
			if(ch != "(") throw new Error("解析错误，错误的(");
			quat.x = getNextNumber();
			quat.y = getNextNumber();
			quat.z = getNextNumber();
			
			//四元数需要一个单位长度
			var t : Number = 1 - quat.x * quat.x - quat.y * quat.y - quat.z * quat.z;
			quat.w = t < 0 ? 0 : - Math.sqrt(t);
			
			if (getNextToken() != ")") throw new Error("解析错误，错误的)");
			
			return quat;
		}
		
		/**
		 * 获取Vector3d
		 */
		private function parseVector3D() : Vector3D
		{
			var vec : Vector3D = new Vector3D();
			var ch : String = getNextToken();
			
			if(ch != "(") throw new Error("解析错误，错误的(");
			vec.x = getNextNumber();
			vec.y = getNextNumber();
			vec.z = getNextNumber();
			
			if(getNextToken() != ")") throw new Error("解析错误，错误的)");
			
			return vec;
		}
		
		/**
		 * 从数据流中解析下一个浮点型数值
		 */
		private function getNextNumber() : Number
		{
			var f : Number = parseFloat(getNextToken());
			if(isNaN(f)) throw new Error("float type");
			return f;
		}
		
		/**
		 * 解析指令行数据
		 */
		private function parseCMD() : void
		{
			//仅仅忽略指令行属性
			parseLiteralString();
		}
		
		/**
		 * 解析数据流中的逐字符串，一个逐字符是一个序列字符，被两个引号包围
		 */
		private function parseLiteralString() : String
		{
			skipWhiteSpace();
			
			var ch : String = getNextChar();
			var str : String = "";
			
			if(ch != "\"") throw new Error("引号解析错误");
			do{
				if(_reachedEOF) throw new Error("到达文件结尾");
				ch = getNextChar();
				if(ch != "\"") str += ch;
			}while(ch != "\"");
			
			return str;
		}
		
		private function getNextToken() : String
		{
			var ch : String;
			var token : String = "";
			
			while(!_reachedEOF){
				ch = getNextChar();
				if(ch == " " || ch == "\r" || ch == "\n" || ch == "\t"){
					//如果不为注释，跳过
					if(token != COMMENT_TOKEN)
						skipWhiteSpace();
					//如果不为空白, 返回
					if(token != "")
						return token;
				}else token += ch;
				
				if(token == COMMENT_TOKEN) return token;
			}
			
			return token;
		}
		
		/**
		 * 读出数据流中的下一个整型
		 */
		private function getNextInt() : int
		{
			var i : Number = parseInt(getNextToken());
			if(isNaN(i)) throw new Error("解析错误 int type");
			return i;
		}
		
		/**
		 * 跳过下一行
		 */
		private function ignoreLine() : void
		{
			var ch : String;
			while(!_reachedEOF && ch != "\n")
				ch = getNextChar();
		}
		
		/**
		 * 跳过数据流中的空白
		 */
		private function skipWhiteSpace() : void
		{
			var ch : String;
			do {
				ch = getNextChar();
			}while(ch == "\n" || ch == " " || ch == "\r" || ch == "\t");
			
			putBack();
		}
		
		/**
		 * 将最后读出的字符放回数据流
		 */
		private function putBack() : void
		{
			_parseIndex--;
			_chatLineIndex--;
			_reachedEOF = _parseIndex >= _textData.length;
		}
		
		/**
		 * 从数据流中读取下一个字符
		 */
		private function getNextChar() : String
		{
			var ch : String = _textData.charAt(_parseIndex++);
			
			//如果遇到换行符
			if(ch == "\n"){
				++_line;
				_chatLineIndex = 0;
			}
			//如果遇到回车符
			else if(ch != "\r"){
				++_chatLineIndex;
			}
			
			if(_parseIndex >= _textData.length)
				_reachedEOF = true;
			
			return ch;
		}
		
		public var num_joints : int;
		public var md5_joint : Vector.<IJoint>;
		public var num_meshes : int;
		public var md5_mesh : Vector.<MD5MeshData>;
		public var maxJointCount : int;
		
		
		private var _textData : String;
		private var _reachedEOF : Boolean;
		private var _parseIndex : int = 0;
		private var _line : int = 0;
		private var _chatLineIndex : int = 0;
		private var _version : int;
		private var _shaders : Vector.<String>;
		private var _rotationQuat : Quaternion;
		
		/**注释**/
		private static const COMMENT_TOKEN : String = "//";
		/**版本**/
		private static const VERSION_TOKEN : String = "MD5Version";
		/**指令**/
		private static const COMMAND_LINE_TOKEN : String = "commandline";
		/**总骨骼数**/
		private static const NUM_JOINTS_TOKEN : String = "numJoints";
		/**总网格数**/
		private static const NUM_MESHES_TOKEN : String = "numMeshes";
		/**骨骼令牌**/
		private static const JOINTS_TOKEN : String = "joints";
		/**网格令牌**/
		private static const MESH_TOKEN : String = "mesh";
		/**网格shader令牌**/
		private static const MESH_SHADER_TOKEN : String = "shader";
		/**网格总顶点令牌**/
		private static const MESH_NUM_VERTS_TOKEN : String = "numverts";
		/**网格顶点令牌**/
		private static const MESH_VERT_TOKEN : String = "vert";
		/**网格总三角形令牌**/
		private static const MESH_NUM_TRIS_TOKEN : String = "numtris";
		/**网格三角形令牌**/
		private static const MESH_TRI_TOKEN : String = "tri";
		/**网格总权重令牌**/
		private static const MESH_NUM_WEIGHTS_TOKEN : String = "numweights";
		/**网格权重令牌**/
		private static const MESH_WEIGHT_TOKEN : String = "weight";
	}
}