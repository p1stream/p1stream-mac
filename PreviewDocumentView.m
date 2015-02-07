#import "PreviewDocumentView.h"
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


@implementation PreviewDocumentView {
    NSString *_mixerId;
    PreviewClient *_client;

    IOSurfaceRef _surfaceRef;
    bool _ready;
    GLuint _texture;
}

- (instancetype)initWithFrame:(NSRect)frameRect
{
    // Ensure we use a context with core profile.
    NSOpenGLPixelFormatAttribute attrs[] = {
        NSOpenGLPFADepthSize, 24,
        NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion3_2Core,
        0
    };
    NSOpenGLPixelFormat *format = [[NSOpenGLPixelFormat alloc] initWithAttributes:attrs];
    if (!format)
        return nil;

    return [super initWithFrame:frameRect pixelFormat:format];
}

- (void)dealloc
{
    self.mixerId = nil;
}

- (NSString *)mixerId
{
    return _mixerId;
}

- (void)setMixerId:(NSString *)mixerId
{
    [_client destroy];
    _client = nil;

    _mixerId = mixerId;

    if (_mixerId) {
        // Create the preview service client.
        _client = [[PreviewClient alloc] initWithMixerId:_mixerId];
        _client.delegate = self;
    }
}

- (void)prepareOpenGL
{
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
        return;

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
        return;
    }

    _ready = true;

    [self updateTexture];
}

- (void)updateTexture
{
    if (!_ready)
        return;

    [self.openGLContext makeCurrentContext];

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
            self.openGLContext.CGLContextObj, GL_TEXTURE_RECTANGLE, GL_RGBA8,
            width, height, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, _surfaceRef, 0
        );
        if (cglRet != kCGLNoError) {
            glDeleteTextures(1, &_texture);
            _texture = 0;

            NSLog(@"CGLTexImageIOSurface2D error 0x%x", cglRet);
        }
    }

}

- (void)clearGLContext
{
    _ready = 0;
    _texture = 0;
    [super clearGLContext];
}

- (void)reshape
{
    self.needsLayout = TRUE;

    const CGSize size = self.frame.size;
    glViewport(0, 0, size.width, size.height);
}

- (void)layout
{
    self.frameSize = self.superview.bounds.size;
    [super layout];
}

- (void)drawRect:(NSRect)dirtyRect
{
    [self render];
}

- (BOOL)isOpaque
{
    return TRUE;
}

- (void)previewSetSurface:(IOSurfaceRef)surfaceRef
{
    if (_surfaceRef != NULL)
        CFRelease(_surfaceRef);

    _surfaceRef = surfaceRef;

    if (_surfaceRef != NULL)
        CFRetain(_surfaceRef);

    [self updateTexture];
    [self render];
}

- (void)previewUpdated
{
    [self render];
}

- (void)render
{
    if (!_ready)
        return;

    [self.openGLContext makeCurrentContext];
    glClear(GL_COLOR_BUFFER_BIT);
    if (_texture != 0) {
        glBindTexture(GL_TEXTURE_RECTANGLE, _texture);
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    }
    glFlush();
}

- (void)setDataSource:(WebDataSource *)dataSource
{
}

- (void)dataSourceUpdated:(WebDataSource *)dataSource
{
    NSString *str = [[NSString alloc] initWithData:dataSource.data encoding:NSUTF8StringEncoding];
    if (str)
        self.mixerId = str;
}

- (void)viewWillMoveToHostWindow:(NSWindow *)hostWindow
{
}

- (void)viewDidMoveToHostWindow
{
}

@end
