package starling.extensions.md5
{
	import com.adobe.utils.AGALMiniAssembler;
	
	import flash.display.Bitmap;
	import flash.display3D.Context3D;
	import flash.display3D.Context3DCompareMode;
	import flash.display3D.Context3DProgramType;
	import flash.display3D.Context3DTextureFormat;
	import flash.display3D.Context3DTriangleFace;
	import flash.display3D.Context3DVertexBufferFormat;
	import flash.display3D.IndexBuffer3D;
	import flash.display3D.Program3D;
	import flash.display3D.VertexBuffer3D;
	import flash.display3D.textures.Texture;
	import flash.events.Event;
	import flash.geom.Matrix3D;
	import flash.geom.Rectangle;
	import flash.geom.Vector3D;
	import flash.utils.ByteArray;
	
	import starling.core.RenderSupport;
	import starling.core.Starling;
	import starling.display.DisplayObject;
	import starling.errors.MissingContextError;
	import starling.extensions.md5.model.MD5Joint;
	import starling.extensions.md5.model.MD5MeshData;
	import starling.extensions.md5.model.MD5Vertex;
	import starling.extensions.md5.model.MD5Weight;
	import starling.extensions.md5.parser.MD5MeshParser;

	/**
	 * Author : 苍白的茧
	 * Date : 2013-10-25 下午4:16:18
	 */
	public class DisplayObject3D extends DisplayObject
	{
		public function DisplayObject3D(modelData : ByteArray = null)
		{
			if(null == modelData) return;
			
			init(modelData);
		}
		
		public function init(modelData : ByteArray) : void
		{
			m_context = Starling.current.context;
//			initDebug();
			
			m_modelData = modelData;
			m_meshList = new Vector.<Md5Mesh>();

			createTexture();
			m_md5MeshParser = new MD5MeshParser();
			m_md5MeshParser.addEventListener(Event.COMPLETE, onMeshLoaded);
			m_md5MeshParser.load(m_modelData);
			
			registerPrograms(m_context);
		}
		
		private function createTexture() : void
		{
			var len : int = m_textureCache.length;
			for(var i : int = 0; i < len; i++){
				var data : Bitmap = m_textureCache.shift();
				var t : Texture = m_context.createTexture(data.width,data.height,Context3DTextureFormat.BGRA,false);
				t.uploadFromBitmapData(data.bitmapData);
				m_textureCache.push(t);
			}
		}
		
		private var debugVertexBuffer : VertexBuffer3D;
		private var debugIndexBuffer : IndexBuffer3D;
		private var debugUvBuffer : VertexBuffer3D;
		private var debugMat : Matrix3D;
		private function initDebug() : void
		{
			var m_cubeVertex : Vector.<Number>;
			var m_cubeIndex : Vector.<uint>;
			var m_cubeUV : Vector.<Number>;
			debugMat = new Matrix3D();
			
			m_cubeVertex = new Vector.<Number>();
			m_cubeVertex.push(-1,-1,-1);//左下
			m_cubeVertex.push(-1,1,-1);//左上
			m_cubeVertex.push(1,1,-1);//右上
			m_cubeVertex.push(1,-1,-1);//右下
			m_cubeVertex.push(-1,-1,1);
			m_cubeVertex.push(-1,1,1);
			m_cubeVertex.push(1,1,1);
			m_cubeVertex.push(1,-1,1);
			
			m_cubeIndex = new Vector.<uint>();
			m_cubeIndex.push(0,1,2);
			m_cubeIndex.push(0,2,3);
			m_cubeIndex.push(4,6,5);
			m_cubeIndex.push(4,7,6);
			m_cubeIndex.push(4,5,1);
			m_cubeIndex.push(4,1,0);
			m_cubeIndex.push(3,2,6);
			m_cubeIndex.push(3,6,7);
			m_cubeIndex.push(1,5,6);
			m_cubeIndex.push(1,6,2);
			m_cubeIndex.push(4,0,3);
			m_cubeIndex.push(4,3,7);
			
			m_cubeUV = new Vector.<Number>();
			//正面
			m_cubeUV.push(1,1); 
			m_cubeUV.push(1,0);
			m_cubeUV.push(0,0);
			m_cubeUV.push(0,1);
			
			m_cubeUV.push(0,1); 
			m_cubeUV.push(0,0);
			m_cubeUV.push(1,0);
			m_cubeUV.push(1,1);
			
			debugVertexBuffer = m_context.createVertexBuffer(m_cubeVertex.length / 3, 3);
			debugVertexBuffer.uploadFromVector(m_cubeVertex,0,m_cubeVertex.length / 3);
			
			debugIndexBuffer = m_context.createIndexBuffer(m_cubeIndex.length);
			debugIndexBuffer.uploadFromVector(m_cubeIndex,0,m_cubeIndex.length);
			
			debugUvBuffer = m_context.createVertexBuffer(m_cubeUV.length / 2, 2);
			debugUvBuffer.uploadFromVector(m_cubeUV, 0, m_cubeUV.length / 2);
		}
		
		private var m_textureCache : Array = [];
		public function setTexture(data : Bitmap) : void
		{
			m_textureCache.push(data);
		}
		
		private function onMeshLoaded(e:Event) : void
		{
			var meshData : MD5MeshData;
			var md5Mesh : Md5Mesh;
			for each(meshData in m_md5MeshParser.md5_mesh)
			{
				md5Mesh = new Md5Mesh();
				md5Mesh.uvRawData = meshData.getUv();
				md5Mesh.indexRawData = meshData.getIndex();
				
				//取出最大关节数
				var maxJointCount : int = m_md5MeshParser.maxJointCount;
				var vertexLen : int = meshData.md5_vertex.length;
				
				var vertexRawData : Vector.<Number> = new Vector.<Number>();
				var jointIndexRawData : Vector.<Number> = new Vector.<Number>();
				var jointWeightRawData : Vector.<Number> =  new Vector.<Number>();
				
				var nonZeroWeights : int;
				var l : int = 0;
				var finalVertex : Vector3D;
				var vertex : MD5Vertex;
				
				for(var i : int = 0; i < vertexLen; i++)
				{
					finalVertex = new Vector3D();
					vertex = meshData.md5_vertex[i];
					nonZeroWeights = 0;
					//遍历每个顶点的总权重
					for(var j : int = 0; j < vertex.weight_count; j++)
					{
						//取出当前顶点的权重
						var weight : MD5Weight = meshData.md5_weight[vertex.weight_index + j];
						//取出当前顶点对应的关节
						var joint2 : MD5Joint = m_md5MeshParser.md5_joint[weight.jointID] as MD5Joint;
						
						//将权重转换为关节坐标系为参考的值
						var wv : Vector3D = joint2.bindPose.transformVector(weight.pos);
						//进行权重缩放
						wv.scaleBy(weight.bias);
						//输出转换后的顶点
						finalVertex = finalVertex.add(wv);
						
						jointIndexRawData[l] = weight.jointID * 2;
						jointWeightRawData[l++] = weight.bias;
						++nonZeroWeights;
					}
					
					for(j = nonZeroWeights; j < maxJointCount; ++j)
					{
						jointIndexRawData[l] = 0;
						jointWeightRawData[l++] = 0;
					}
					
					var startIndex : int = i * 3;
					vertexRawData[startIndex] = finalVertex.x; 
					vertexRawData[startIndex+1] = finalVertex.y; 
					vertexRawData[startIndex+2] = finalVertex.z; 
				}
				
				md5Mesh.vertexRawData = vertexRawData;
				md5Mesh.jointIndexRawData = jointIndexRawData;
				md5Mesh.jointWeightRawData = jointWeightRawData;
				md5Mesh.numTriangles = meshData.num_tris;
				
				if(m_textureCache.length)
					md5Mesh.texture = m_textureCache.shift();
				
				
				md5Mesh.finalMatrix.identity()
				md5Mesh.finalMatrix.appendRotation(90, Vector3D.X_AXIS);
				m_meshList.push(md5Mesh);
			}
			m_meshNum = m_meshList.length;
		}
		
		/**
		 * 更新相机到投影矩阵
		 */
		private var m_proj : Matrix3D;
		private var m_aspect : Number;
		private var m_viewport : Rectangle;
		private var m_near : Number = .01;
		private var m_far : Number = 5000;
		private var m_zoom : int = 1;
		private function updateViewToClip() : void
		{
			m_proj = new Matrix3D();
			m_aspect = Starling.current.stage.stageWidth/Starling.current.stage.stageHeight;
			m_viewport = Starling.current.viewPort;
			
			var rawData : Vector.<Number> = m_proj.rawData;
			var w : Number;
			var h : Number;
			var n : Number = m_near;
			var f : Number = m_far;
			var a : Number = m_aspect;w = m_viewport.width;
			h = m_viewport.height;var y : Number = (1 / m_zoom) * a;
			var x : Number = y / a;
			rawData[0] = x;
			rawData[5] = y;
			rawData[10] = f / (n - f);
			rawData[11] = -1;
			rawData[14] = (f * n) / (n - f);
			rawData[0] = (x / (w / m_viewport.width));
			rawData[5] = (y / (h / m_viewport.height));
			rawData[8] = (1 - (m_viewport.width / w)) - ((m_viewport.x / w) * 2);
			rawData[9] = (-1 + (m_viewport.height / h)) + ((m_viewport.y / h) * 2);
			m_proj.copyRawDataFrom(rawData);
		}
		
		public override function render(support:RenderSupport, parentAlpha:Number):void
		{
//			m_context.clear();
			m_context.setCulling(Context3DTriangleFace.BACK);
			m_context.setDepthTest(true, Context3DCompareMode.LESS);
			if(m_meshNum)
			{
				if(null == m_proj)updateViewToClip();

				if (m_context == null) throw new MissingContextError();
				renderCuston(m_context,support);
			}
			m_context.setCulling(Context3DTriangleFace.NONE);
			m_context.setDepthTest(false, Context3DCompareMode.ALWAYS);
//			renderDebug(m_context);
//			m_context.present();
		}
		
		private function renderDebug(context : Context3D) : void
		{
			m_finalMat.identity();
			m_finalMat.append(debugMat);
			m_finalMat.append(m_viewMat);
			
			m_context.setProgram(m_program);
			m_context.setVertexBufferAt(0,debugVertexBuffer,0,"float3");
			m_context.setVertexBufferAt(1,debugUvBuffer,0,"float2");
			m_context.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX,0,m_finalMat,true);
			
			m_context.drawTriangles(debugIndexBuffer);
		}
		
		private var m_viewMat : Matrix3D = new Matrix3D();
		private var m_finalMat : Matrix3D = new Matrix3D();
		private var m_helpMat : Matrix3D = new Matrix3D();
		
		public var t : Number = 0, z : Number = 500;
		private function renderCuston(context : Context3D, support : RenderSupport) : void
		{
			var degree : Number = t++ % 360;
			
			for each(var md5Mesh : Md5Mesh in m_meshList)
			{
				if(null == md5Mesh.vertexBuffer)
					md5Mesh.createVertexBuffer(context);
				
				if(null == md5Mesh.indexBuffer)
					md5Mesh.createIndexBuffer(context);
				
				if(null == md5Mesh.uvBuffer)
					md5Mesh.createUvBuffer(context);
				
				m_viewMat.identity();
				m_viewMat.appendTranslation(x,y,z);
				m_viewMat.invert();
				
				m_finalMat.identity();
				m_finalMat.append(md5Mesh.finalMatrix);
//				m_finalMat.appendTranslation(30,30,0);
				m_finalMat.appendRotation(180,Vector3D.X_AXIS);
				m_finalMat.appendRotation(degree,Vector3D.Y_AXIS);
				m_finalMat.append(m_viewMat);
				m_finalMat.append(m_proj);
				
//				MatrixUtil.convertTo3D(support.projectionMatrix,m_helpMat);
//				m_finalMat.append(m_helpMat);
				
				context.setProgram(m_program);
				
//				context.setProgramConstantsFromVector(Context3DProgramType.VERTEX, 0, sRenderAlpha, 1);
				context.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX,0,m_finalMat,true);
//				context.setProgramConstantsFromVector(Context3DProgramType.VERTEX, 2, Vector.<Number>([255,0,0,255]), 1);
				
				context.setVertexBufferAt(0, md5Mesh.vertexBuffer,0,Context3DVertexBufferFormat.FLOAT_3);
				context.setVertexBufferAt(1, md5Mesh.uvBuffer,0,Context3DVertexBufferFormat.FLOAT_2);
				
				context.setTextureAt(0, md5Mesh.texture);
				context.drawTriangles(md5Mesh.indexBuffer,0, md5Mesh.numTriangles);
			}
			
			context.setTextureAt(0,null);
			context.setVertexBufferAt(1,null);
			context.setVertexBufferAt(0,null);
		}
		
		private static function registerPrograms(context : Context3D) : void
		{
			var assembler : AGALMiniAssembler = new AGALMiniAssembler();
			var vertexProgramCode : String;
			var fragmentProgramCode : String;
			
			// this is the input data we'll pass to the shaders:
			// 
			// va0 -> position
			// va1 -> color
			// va2 -> texCoords
			// vc0 -> alpha
			// vc1 -> mvpMatrix
			// fs0 -> texture
			
			vertexProgramCode = 
				"m44 op va0 vc0\n" + 
				"mov v0 va1\n";
			
			fragmentProgramCode = 
				"tex ft0 v0 fs0<2d,linear,repeat>\n"+
				"mov oc ft0 \n";
			
			m_program = context.createProgram();
			m_program.upload(assembler.assemble(Context3DProgramType.VERTEX,vertexProgramCode),
				assembler.assemble(Context3DProgramType.FRAGMENT,fragmentProgramCode));
		}
		
		private var m_md5MeshParser : MD5MeshParser;
		private var m_meshList : Vector.<Md5Mesh>;
		private var m_modelData : ByteArray;
		private var m_meshNum : int;
		
		protected static var m_program : Program3D;
		
		protected var m_context : Context3D;
		
		private static var sRenderAlpha:Vector.<Number> = new <Number>[1.0, 1.0, 1.0, 1.0];
		private static const MD5_MODEL_PROGRAM_NAME : String = "md5ModelProgramName";
	}
}
import flash.display3D.Context3D;
import flash.display3D.IndexBuffer3D;
import flash.display3D.VertexBuffer3D;
import flash.display3D.textures.Texture;
import flash.geom.Matrix3D;

class Md5Mesh
{
	public var uvRawData : Vector.<Number>;
	public var vertexRawData : Vector.<Number>;
	public var indexRawData : Vector.<uint>;
	public var normalRawData : Vector.<Number>;
	public var jointIndexRawData : Vector.<Number>;
	public var jointWeightRawData : Vector.<Number>;
	public var numTriangles : int;
	public var texture : Texture;
	
	public var vertexBuffer : VertexBuffer3D;
	public var indexBuffer : IndexBuffer3D;
	public var uvBuffer : VertexBuffer3D;
	public var finalMatrix : Matrix3D = new Matrix3D();
	
	public function createVertexBuffer(context : Context3D) : void
	{
		vertexBuffer = context.createVertexBuffer(vertexRawData.length/3,3);
		vertexBuffer.uploadFromVector(vertexRawData,0,vertexRawData.length/3);
	}
	
	public function createIndexBuffer(context : Context3D) : void
	{
		indexBuffer = context.createIndexBuffer(indexRawData.length);
		indexBuffer.uploadFromVector(indexRawData,0,indexRawData.length);
	}
	
	public function createUvBuffer(context : Context3D) : void
	{
		uvBuffer = context.createVertexBuffer(uvRawData.length/2,2);
		uvBuffer.uploadFromVector(uvRawData,0,uvRawData.length/2);
	}
}