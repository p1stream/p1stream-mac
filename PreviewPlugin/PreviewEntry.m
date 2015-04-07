#import <WebKit/npapi.h>
#import <QuartzCore/QuartzCore.h>

#import "PreviewLayer.h"

static NPNetscapeFuncs *browser_fns;

NPError NP_Initialize(NPNetscapeFuncs *fns)
{
    browser_fns = fns;
    return NPERR_NO_ERROR;
}

NPError NP_GetEntryPoints(NPPluginFuncs *fns)
{
    fns->version = 11;
    fns->size = sizeof(NPPluginFuncs);

    fns->newp          = NPP_New;
    fns->destroy       = NPP_Destroy;
    fns->setwindow     = NPP_SetWindow;
    fns->newstream     = NPP_NewStream;
    fns->destroystream = NPP_DestroyStream;
    fns->asfile        = NPP_StreamAsFile;
    fns->writeready    = NPP_WriteReady;
    fns->write         = NPP_Write;
    fns->print         = NPP_Print;
    fns->event         = NPP_HandleEvent;
    fns->urlnotify     = NPP_URLNotify;
    fns->getvalue      = NPP_GetValue;
    fns->setvalue      = NPP_SetValue;

    return NPERR_NO_ERROR;
}

void NP_Shutdown(void)
{
}

NPError NPP_New(NPMIMEType pluginType, NPP instance, uint16_t mode, int16_t argc, char *argn[], char *argv[], NPSavedData *saved)
{
    NPError err;

    instance->pdata = NULL;

    NPBool bVal;
    err = browser_fns->getvalue(instance, NPNVsupportsCoreAnimationBool, &bVal);
    if (err != NPERR_NO_ERROR || !bVal)
        return NPERR_INCOMPATIBLE_VERSION_ERROR;

    err = browser_fns->setvalue(instance, NPPVpluginDrawingModel, (void *)NPDrawingModelCoreAnimation);
    if (err != NPERR_NO_ERROR)
        return NPERR_GENERIC_ERROR;

    const char *mixerId = NULL;
    for (int16_t i = 0; i < argc; i++) {
        if (strcmp(argn[i], "mixerId") == 0) {
            mixerId = argv[i];
            break;
        }
    }
    if (mixerId == NULL)
        return NPERR_INVALID_PARAM;

    PreviewLayer *layer = [[PreviewLayer alloc] init];
    layer.mixerId = [NSString stringWithCString:mixerId encoding:NSUTF8StringEncoding];
    instance->pdata = (void *) CFBridgingRetain(layer);

    return NPERR_NO_ERROR;
}

NPError NPP_Destroy(NPP instance, NPSavedData **save)
{
    if (instance->pdata != NULL) {
        CFRelease(instance->pdata);
        instance->pdata = NULL;
    }

    return NPERR_NO_ERROR;
}

NPError NPP_SetWindow(NPP instance, NPWindow *window)
{
    return NPERR_NO_ERROR;
}


NPError NPP_NewStream(NPP instance, NPMIMEType type, NPStream *stream, NPBool seekable, uint16_t *stype)
{
    *stype = NP_ASFILEONLY;
    return NPERR_NO_ERROR;
}

NPError NPP_DestroyStream(NPP instance, NPStream *stream, NPReason reason)
{
    return NPERR_NO_ERROR;
}

int32_t NPP_WriteReady(NPP instance, NPStream *stream)
{
    return 0;
}

int32_t NPP_Write(NPP instance, NPStream *stream, int32_t offset, int32_t len, void *buffer)
{
    return 0;
}

void NPP_StreamAsFile(NPP instance, NPStream *stream, const char *fname)
{
}

void NPP_Print(NPP instance, NPPrint *platformPrint)
{
}

int16_t NPP_HandleEvent(NPP instance, void *event)
{
    return 0;
}

void NPP_URLNotify(NPP instance, const char *url, NPReason reason, void *notifyData)
{
}

NPError NPP_GetValue(NPP instance, NPPVariable variable, void *value)
{
    switch (variable) {
        case NPPVpluginCoreAnimationLayer:
            *(void **) value = instance->pdata;
            return NPERR_NO_ERROR;

        default:
            return NPERR_GENERIC_ERROR;
    }
}

NPError NPP_SetValue(NPP instance, NPNVariable variable, void *value)
{
    return NPERR_GENERIC_ERROR;
}
