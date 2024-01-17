Shader "Unlit/Liquid"
{
    Properties
    {
        _MainTex("Diffuse", 2D) = "white" {}
        _TintColor("Tint", Color) = (0,0,0,1)
        _Cube("Reflection Map", Cube) = "" {}
        _ReflectionAmount("Reflection Amount", Range(0.0,1.0)) = 0.5
        _BlendHeight("Blend Height", Float) = 0.5
        _CutoffHeight("Cutoff Height", Float) = 0.5
    }

    HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    ENDHLSL

    SubShader
    {
        Tags
        {
            "RenderType"="Geometry" "RenderQueue"="Geometry" "RenderPipeline" = "UniversalPipeline"
        }
        Cull Off

        Pass
        {
            HLSLPROGRAM
            #pragma vertex unlit_vertex
            #pragma fragment unlit_fragment

            uniform samplerCUBE _Cube;

            struct Attributes
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 color : COLOR;
                float2 uv : TEXCOORD2;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 pos : SV_POSITION;
                float3 normalDir : TEXCOORD0;
                float3 viewDir : TEXCOORD1;
                float4 color : COLOR;
                float2 uv : TEXCOORD2;
                float2 uvWithTimeOffset : TEXCOORD3;
                float2 uvWithTimeAndPositionOffset : TEXCOORD4;
                float3 worldPos : TEXCOORD5;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            CBUFFER_START(UnityPerMaterial)
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_MainTex);
            float4 _MainTex_ST;
            half4 _TintColor;
            half _ReflectionAmount;
            half _BlendHeight;
            half _CutoffHeight;
            CBUFFER_END

            Varyings unlit_vertex(Attributes attributes)
            {
                Varyings o = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(attributes);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);


                o.viewDir = TransformObjectToWorld(attributes.vertex).xyz - _WorldSpaceCameraPos;
                o.normalDir = normalize(TransformWorldToObject(attributes.normal).xyz);

                o.pos = TransformObjectToHClip(attributes.vertex);
                o.uv = TRANSFORM_TEX(attributes.uv, _MainTex);
                o.color = _TintColor;
                o.worldPos = mul(unity_ObjectToWorld, attributes.vertex.xyz);

                // Calculate UV coordinates with time offset for first bubble layer
                o.uvWithTimeOffset = float2(o.pos.x, o.pos.y + _Time.y * 0.5);

                // Calculate UV coordinates for second bubble layer (slightly offset and slower)
                o.uvWithTimeAndPositionOffset = float2(o.pos.x + 25.5, o.pos.y + _Time.y * 0.15);
                return o;
            }

            float4 unlit_fragment(Varyings i, half facing : VFACE) : SV_Target
            {
                // Discard pixels above the cutoff height
                if (i.worldPos.y > _CutoffHeight)
                {
                    discard;
                }

                float4 bubble_tex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uvWithTimeAndPositionOffset * 1);

                // If facing away from the camera, return a solid color
                if (facing < 0.0)
                {
                    bubble_tex.rgb = lerp(bubble_tex.rgb, i.color.rgb * 0.18, 0.95);
                    return float4(bubble_tex.rgb, 1);
                }

                // Calculate reflection
                const float3 reflected_dir = reflect(i.viewDir, normalize(i.normalDir));
                float3 diffuse_reflection = texCUBE(_Cube, reflected_dir);
                diffuse_reflection = lerp(diffuse_reflection, i.color * 0.5, 0.8);

                // Sample main texture with UV coordinates offset by time
                bubble_tex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uvWithTimeOffset * 1);

                // Blend the two texture samples
                bubble_tex.rgb = lerp(bubble_tex.rgb,
                                      SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uvWithTimeAndPositionOffset * 1).
                                      rgb, 0.5);

                // Calculate blend factor based on the relative height of the current pixel within the range from the bottom of the mesh to the cutoff height
                const float blendFactor = saturate(1 + (i.worldPos.y - _CutoffHeight) / (_BlendHeight - _CutoffHeight));

                // Blend with reflection based on blend factor and reflection amount
                bubble_tex.rgb = lerp(bubble_tex + diffuse_reflection, diffuse_reflection,
                                      _ReflectionAmount * blendFactor).rgb * i.color;

                // Set the foam height to be a fixed size based on the cutoff height
                const float foamHeight = _CutoffHeight * 0.9; // 90% of the cutoff height

                // If above the foam height, blend with a slightly off version of the main color
                if (i.worldPos.y > foamHeight)
                {
                    bubble_tex.rgb = lerp(bubble_tex.rgb, i.color.rgb * 0.25, 0.5);
                }

                return float4(bubble_tex.rgb, 1);
            }
            ENDHLSL
        }
    }
}