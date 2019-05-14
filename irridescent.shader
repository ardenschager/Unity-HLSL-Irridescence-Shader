Shader "Shaders/Irridescent" {
	Properties {
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_NormalTex("Normal Map", 2D) = "bump" {}
		_MetallicTex("Metallic Map", 2D) = "Black" {}
		_MetallicGain("Metallic Gain", Range(-1, 1)) = 0.0
		_OcclusionTex("Occlusion Map", 2D) = "white" {}
		_Glossiness ("Smoothness", Range(0,1)) = 0.5

		_IrridescentFade("Irridescent Opacity", Range(0, 1)) = 1.0
		_Distance("Nanoscale Distance (nm)", Range(0, 10000)) = 1600 //nanometer
		_Wavelengths("Octaves", Range(0, 20)) = 8.0
		_NoiseFactor("Noise Factor", Range(0, 1)) = 0.0
		_MetallicInfluence("Metallic Channel Influence", Range(1, 0)) = 1.0

		_RedFilter("Red Filter", Range(0, 5)) = 1.0
		_GreenFilter("Green Filter", Range(0, 5)) = 1.0
		_BlueFilter("Blue Filter", Range(0, 5)) = 1.0
		_RedOffset("Red Offset", Range(-1, 1)) = 0.0
		_GreenOffset("Green Offset", Range(-1, 1)) = 0.0
		_BlueOffset("Blue Offset", Range(-1, 1)) = 0.0
		_RedGain("Red Gain", Range(0, 1)) = 0.0
		_GreenGain("Green Gain", Range(0, 1)) = 0.0
		_BlueGain("Blue Gain", Range(0, 1)) = 0.0
	}
	SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 200

		CGPROGRAM
		// Physically based Standard lighting model, and enable shadows on all light types
		#pragma surface surf Diffraction fullforwardshadows

		// Use shader model 3.0 target, to get nicer looking lighting
		#pragma target 3.0
		#include "UnityCG.cginc"
		#include "UnityPBSLighting.cginc"

		struct Input {
			float2 uv_MainTex;
			float3 viewDir;
		};

		sampler2D _MainTex;
		sampler2D _NormalTex;
		sampler2D _OcclusionTex;
		sampler2D _MetallicTex;
		fixed _MetallicGain;
		half _Glossiness;

		fixed _IrridescentFade;
		fixed _Distance;
		fixed _Wavelengths;
		float _NoiseFactor;
		fixed _MetallicInfluence;

		fixed _RedGain;
		fixed _GreenGain;
		fixed _BlueGain;
		fixed _RedFilter;
		fixed _GreenFilter;
		fixed _BlueFilter;
		fixed _RedOffset;
		fixed _GreenOffset;
		fixed _BlueOffset;

		float3 worldNorm;
		float3 vd;



		inline fixed3 bump3y (fixed3 x, fixed3 yoffset)
		{
			 float3 y = 1 - x * x;
			 y = saturate(y-yoffset);
			 return y;
		}

		// Based on GPU Gems
		// Optimised by Alan Zucconi
		fixed3 spectral_zucconi6 (float w)
		{
			 // w: [400, 700]
			 // x: [0,   1]
			 fixed x = saturate((w - 400.0)/ 300.0);
			 fixed3 filter = fixed3(_RedFilter, _GreenFilter, _BlueFilter);
			 fixed3 xoffset = fixed3(_RedOffset, _GreenOffset, _BlueOffset);
			 fixed3 ygain = fixed3(_RedGain, _GreenGain, _BlueGain);

			 const float3 c1 = 					float3(3.54585104, 2.93225262, 2.41593945) * filter;
			 const float3 x1 = saturate(float3(0.69549072, 0.49228336, 0.27699880) + xoffset);
			 const float3 y1 = saturate(float3(0.02312639, 0.15225084, 0.52607955) + ygain);

			 const float3 c2 = 					float3(3.90307140, 3.21182957, 3.96587128) * filter;
			 const float3 x2 = saturate(float3(0.11748627, 0.86755042, 0.66077860) + xoffset);
			 const float3 y2 = saturate(float3(0.84897130, 0.88445281, 0.73949448) + ygain);

			 return
			 _IrridescentFade *
			 (bump3y(c1 * (x - x1), y1) +
			 bump3y(c2 * (x - x2), y2)) ;
		}

		float rand(float3 myVector)  {
				return frac(sin( dot(myVector ,float3(12.9898,78.233,45.5432) )) * 43758.5453);
		}


		inline fixed4 LightingDiffraction_Deferred(SurfaceOutputStandard s, UnityGI gi, out half4 outDiffuseOcclusion, out half4 outSpecSmoothness, out half4 outNormal)
		{
			 // Original colour
			 fixed4 pbr = LightingStandard_Deferred(s, vd, gi, outDiffuseOcclusion, outSpecSmoothness, outNormal);

			 // Diffraction grating effect
			 float3 L = gi.light.dir;
			 float3 V = vd;
			 float3 N = worldNorm;

			 float d = _Distance;
			 float cos_ThetaL = dot(L, N);
			 float cos_ThetaV = dot(V, N);
			 float u = abs(cos_ThetaL - cos_ThetaV) + rand(worldNorm) * _NoiseFactor;

			 if (u == 0)
			 return pbr;

			 // Reflection colour
			 fixed3 color = 0;
			 for (int n = 1; n <= _Wavelengths; n++)
			 {
				 float wavelength = u * d / n;
				 color += spectral_zucconi6(wavelength);
			 }
			 color = saturate(color * saturate(s.Metallic + _MetallicInfluence));

			 // Adds the reflection to the material colour
			 pbr.rgb += color;
			 return pbr;
		}

		inline void LightingDiffraction_GI(
                SurfaceOutputStandard s,
                UnityGIInput data,
                inout UnityGI gi)
    {
        LightingStandard_GI(s, data, gi);
    }

		// inline fixed3 Diffraction(SurfaceOutputStandard s, fixed3 viewDir, UnityGI gi)
		// {
		//
		// 	 // --- Diffraction grating effect ---
		// 	 float3 L = gi.light.dir;
		// 	 float3 V = viewDir;
		// 	 float3 N = worldNorm;
		//
		// 	 float d = _Distance;
		// 	 float cos_ThetaL = dot(L, N);
		// 	 float cos_ThetaV = dot(V, N);
		// 	 float u = abs(cos_ThetaL - cos_ThetaV);
		//
		// 	 if (u == 0)
		// 	 return pbr;
		//
		// 	 // Reflection colour
		// 	 fixed3 color = 0;
		// 	 for (int n = 1; n <= _Wavelengths; n++)
		// 	 {
		// 		 float wavelength = u * d / n;
		// 		 color += spectral_zucconi6(wavelength);
		// 	 }
		// 	 color = saturate(color);
		//
		// 	 // Adds the reflection to the material colour
		// 	 return color;
		// }



		void surf (Input IN, inout SurfaceOutputStandard o) {

			//float3 viewDir = UNITY_MATRIX_IT_MV[2].xyz;

			//tex2D (_MainTex, IN.uv_MainTex) *
			fixed4 c = tex2D(_MainTex, IN.uv_MainTex);
			// Metallic and smoothness come from slider variables
			o.Normal = UnpackNormal(tex2D(_NormalTex, IN.uv_MainTex));
			vd = IN.viewDir;
			worldNorm = dot(normalize(vd), o.Normal);
			o.Albedo = c.rgb;

			o.Metallic = saturate(tex2D(_MetallicTex, IN.uv_MainTex) + _MetallicGain);
			o.Occlusion = tex2D(_OcclusionTex, IN.uv_MainTex);
			o.Smoothness = _Glossiness;
			o.Alpha = c.a;
		}
		ENDCG
	}
	FallBack "Diffuse"
}
