Shader "Unlit/Glass" {
    Properties {
        _TintColor("Tint", Color) = (0,0,0,1)
        _Cube("Reflection Map", Cube) = "" {}
    }

    HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    ENDHLSL

    SubShader {
        Tags { "RenderType"="Transparent" "RenderQueue"="Transparent" "RenderPipeline" = "UniversalPipeline" }

        Blend One One
        Cull Back

        Pass {
            HLSLPROGRAM
            #pragma vertex vertex_shader
            #pragma fragment fragment_shader

            uniform samplerCUBE _Cube;

            struct Attributes {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 color : COLOR;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings {
                float4 pos : SV_POSITION;
                float3 normalDir : TEXCOORD0;
                float3 viewDir : TEXCOORD1;
                float4 color : COLOR;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            CBUFFER_START(UnityPerMaterial)
            half4 _TintColor;
            half _ReflectionAmount;
            half _BlendHeight;
            CBUFFER_END

            Varyings vertex_shader(Attributes attributes) {
                Varyings o = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(attributes);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                // Calculate view direction and normal direction
                o.viewDir = TransformObjectToWorld(attributes.vertex).xyz - _WorldSpaceCameraPos;
                o.normalDir = normalize(TransformWorldToObject(attributes.normal).xyz);

                // Transform vertex to clip space
                o.pos = TransformObjectToHClip(attributes.vertex);

                // Set color
                o.color = _TintColor;
                return o;
            }

            float4 fragment_shader(Varyings i) : SV_Target {
                // Calculate reflection
                float3 reflectedDir = reflect(i.viewDir, normalize(i.normalDir));
                float3 diffuseReflection = texCUBE(_Cube, reflectedDir).rgb;

                // Return the final color
                return float4(diffuseReflection, 1.0) * i.color;
            }
            ENDHLSL
        }
    }
}