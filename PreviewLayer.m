#import "PreviewLayer.h"
#include "OpenGL/gl3.h"

static const char *vertexShader =
"#version 150\n"

"uniform sampler2DRect u_Texture;\n"
"in vec2 a_Position;\n"
"in vec2 a_TexCoords;\n"
"out vec2 v_TexCoords;\n"

"void main(void) {\n"
"gl_Position = vec4(a_Position.x, a_Position.y, 0.0, 1.0);\n"
"v_TexCoords = a_TexCoords * textureSize(u_Texture);\n"
"}\n";

static const char *fragmentShader =
"#version 150\n"

"uniform sampler2DRect u_Texture;\n"
"in vec2 v_TexCoords;\n"
"out vec4 o_FragColor;\n"

"void main(void) {\n"
"o_FragColor = texture(u_Texture, v_TexCoords);\n"
"}\n";

static GLuint buildShader(GLuint type, const char *source)
{
    GLuint shader = glCreateShader(type);
    glShaderSource(shader, 1, &source, NULL);
    glCompileShader(shader);

    GLint logSize = 0;
    glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &logSize);
    if (logSize) {
        GLchar log[logSize];
        glGetShaderInfoLog(shader, logSize, NULL, log);
        NSLog(@"%s", log);
    }

    GLint success = GL_FALSE;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &success);

    GLenum err = glGetError();
    if (err != GL_NO_ERROR) {
        NSLog(@"glCompileShader error 0x%x", err);
        return 0;
    }
    if (success != GL_TRUE) {
        NSLog(@"glCompileShader error");
        return 0;
    }

    return shader;
}

static bool buildProgram(GLuint program)
{
    GLuint vs = buildShader(GL_VERTEX_SHADER, vertexShader);
    if (vs == 0)
        return false;

    GLuint fs = buildShader(GL_FRAGMENT_SHADER, fragmentShader);
    if (fs == 0)
        return false;

    glAttachShader(program, vs);
    glAttachShader(program, fs);
    glLinkProgram(program);
    glDetachShader(program, vs);
    glDetachShader(program, fs);

    glDeleteShader(vs);
    glDeleteShader(fs);

    GLint logSize = 0;
    glGetProgramiv(program, GL_INFO_LOG_LENGTH, &logSize);
    if (logSize) {
        GLchar log[logSize];
        glGetProgramInfoLog(program, logSize, NULL, log);
        NSLog(@"%s", log);
    }

    GLint success = GL_FALSE;
    glGetProgramiv(program, GL_LINK_STATUS, &success);

    GLenum err = glGetError();
    if (err != GL_NO_ERROR) {
        NSLog(@"glLinkProgram error 0x%x", err);
        return false;
    }
    if (success != GL_TRUE) {
        NSLog(@"glLinkProgram error");
        return false;
    }

    return true;
}

@implementation PreviewLayer {
    NSString *_mixerId;
    PreviewClient *_client;

    IOSurfaceRef _surfaceRef;
    GLuint _texture;

    BOOL _surfaceChanged;
    BOOL _frameChanged;
}

- (BOOL)isAsynchronous
{
    return TRUE;
}

- (BOOL)needsDisplayOnBoundsChange
{
    return TRUE;
}

- (NSString *)mixerId
{
    return _mixerId;
}

- (void)setMixerId:(NSString *)mixerId
{
    if ([mixerId isEqualToString:_mixerId])
        return;

    if (_client != nil) {
        [_client destroy];
        _client = nil;
    }

    _mixerId = mixerId;
    [self previewSetSurface:NULL];

    if (_mixerId != nil) {
        _client = [[PreviewClient alloc] initWithMixerId:_mixerId];
        _client.delegate = self;
    }
}

- (void)previewSetSurface:(IOSurfaceRef)surfaceRef
{
    if (surfaceRef == _surfaceRef)
        return;

    if (_surfaceRef != NULL)
        CFRelease(_surfaceRef);

    _surfaceRef = surfaceRef;
    _surfaceChanged = _frameChanged = TRUE;

    if (_surfaceRef != NULL)
        CFRetain(_surfaceRef);
}

- (void)previewUpdated
{
    _frameChanged = TRUE;
}

- (void)dealloc
{
    self.mixerId = nil;
}

- (CGLPixelFormatObj)copyCGLPixelFormatForDisplayMask:(uint32_t)mask
{
    CGLPixelFormatObj result = NULL;
    GLint num = 0;
    CGLChoosePixelFormat((CGLPixelFormatAttribute[]) {
        kCGLPFADisplayMask, mask,
        kCGLPFANoRecovery,
        kCGLPFAAccelerated,
        kCGLPFAOpenGLProfile, (CGLPixelFormatAttribute) kCGLOGLPVersion_3_2_Core,
        0
    }, &result, &num);
    return result;
}

- (CGLContextObj)copyCGLContextForPixelFormat:(CGLPixelFormatObj)pf
{
    CGLContextObj ctx = [super copyCGLContextForPixelFormat:pf];
    if (ctx == NULL)
        return NULL;

    CGLError cgl_err = CGLSetCurrentContext(ctx);
    if (cgl_err != kCGLNoError) {
        NSLog(@"Failed to activate OpenGL context: 0x0%x", cgl_err);
        goto error;
    }

    const GLsizei stride = 4 * sizeof(GLfloat);
    const void *tex_offset = (void *)(2 * sizeof(GLfloat));
    const GLfloat data[] = {
        -1, +1, 0, 0,
        -1, -1, 0, 1,
        +1, +1, 1, 0,
        +1, -1, 1, 1
    };
    GLuint vbo;
    glGenBuffers(1, &vbo);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(data), data, GL_STATIC_DRAW);

    GLuint vao;
    glGenVertexArrays(1, &vao);
    glBindVertexArray(vao);

    GLuint program = glCreateProgram();
    glBindAttribLocation(program, 0, "a_Position");
    glBindAttribLocation(program, 1, "a_TexCoords");
    glBindFragDataLocation(program, 0, "o_FragColor");
    if (!buildProgram(program))
        goto error;

    glUseProgram(program);
    glUniform1i(glGetUniformLocation(program, "u_Texture"), 0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, stride, 0);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, stride, tex_offset);
    glEnableVertexAttribArray(0);
    glEnableVertexAttribArray(1);

    glClearColor(0, 0, 0, 1);

    GLenum err = glGetError();
    if (err != GL_NO_ERROR) {
        NSLog(@"OpenGL error 0x%x", err);
        goto error;
    }

    _surfaceChanged = _frameChanged = TRUE;

    return ctx;

error:
    CGLReleaseContext(ctx);
    return NULL;
}

- (BOOL)canDrawInCGLContext:(CGLContextObj)ctx
                pixelFormat:(CGLPixelFormatObj)pf
               forLayerTime:(CFTimeInterval)t
                displayTime:(const CVTimeStamp *)ts
{
    return _frameChanged;
}

- (void)drawInCGLContext:(CGLContextObj)ctx
             pixelFormat:(CGLPixelFormatObj)pf
            forLayerTime:(CFTimeInterval)t
             displayTime:(const CVTimeStamp *)ts
{
    glClear(GL_COLOR_BUFFER_BIT);

    if (_surfaceChanged) {
        if (_texture != 0) {
            glDeleteTextures(1, &_texture);
            _texture = 0;
        }

        if (_surfaceRef != NULL) {
            glGenTextures(1, &_texture);
            glBindTexture(GL_TEXTURE_RECTANGLE, _texture);

            GLsizei width = (GLsizei) IOSurfaceGetWidth(_surfaceRef);
            GLsizei height = (GLsizei) IOSurfaceGetHeight(_surfaceRef);

            CGLError cglRet = CGLTexImageIOSurface2D(
                ctx, GL_TEXTURE_RECTANGLE, GL_RGBA8,
                width, height, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, _surfaceRef, 0
            );
            if (cglRet != kCGLNoError) {
                glDeleteTextures(1, &_texture);
                _texture = 0;

                NSLog(@"CGLTexImageIOSurface2D error 0x%x", cglRet);
            }
        }
    }

    if (_texture != 0) {
        glBindTexture(GL_TEXTURE_RECTANGLE, _texture);
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    }

    [super drawInCGLContext:ctx pixelFormat:pf forLayerTime:t displayTime:ts];
}

@end
