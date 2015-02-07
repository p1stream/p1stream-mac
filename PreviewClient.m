#import "PreviewClient.h"
#include "p1stream_mac_preview.h"

@implementation PreviewClient {
    mach_port_t cClientPort;
    NSPort *clientPort;
}

- (instancetype)initWithMixerId:(NSString *)mixerId
{
    mach_msg_return_t ret;

    self = [super init];
    if (self) {
        // Convert the mixer ID to a C string.
        const char *cMixerId = [mixerId cStringUsingEncoding:NSUTF8StringEncoding];

        // Request a preview channel.
        ret = p1_request_preview(cMixerId, &cClientPort);
        if (ret != MACH_MSG_SUCCESS)
            return nil;

        // Setup a notification for when the other side goes away.
        ret = [self setNoSendersNotificationReceiver:cClientPort];
        if (ret != KERN_SUCCESS) {
            [self destroy];
            return nil;
        }

        // Create an NSPort for the Mach port.
        clientPort = [NSMachPort portWithMachPort:cClientPort
                                          options:NSMachPortDeallocateNone];
        if (!clientPort) {
            [self destroy];
            return nil;
        }
        clientPort.delegate = self;
        [[NSRunLoop currentRunLoop] addPort:clientPort
                                    forMode:NSRunLoopCommonModes];
    }
    return self;
}

- (void)destroy
{
    if (clientPort != nil) {
        // We need to explicitely invalidate the port.
        // FIXME: Do we need to remove it from the runloop?
        [clientPort invalidate];
        clientPort = nil;
    }

    if (cClientPort != MACH_PORT_NULL) {
        // Deallocate the send-once notification right we created.
        [self setNoSendersNotificationReceiver:MACH_PORT_NULL];

        // Destroy our receive right.
        mach_port_destroy(mach_task_self(), cClientPort);
        cClientPort = MACH_PORT_NULL;
    }

    [self.delegate previewSetSurface:NULL];
}

// Set up a notification for when our client port has no more senders, to be
// sent to the given receive right.
- (kern_return_t)setNoSendersNotificationReceiver:(mach_port_t)receiveRight
{
    mach_port_t cPreviousPort;

    kern_return_t ret = mach_port_request_notification(
        mach_task_self(), cClientPort, MACH_NOTIFY_NO_SENDERS, 0,
        cClientPort, MACH_MSG_TYPE_MAKE_SEND_ONCE, &cPreviousPort
    );

    // Deallocate the old send or send-once right, if there was one.
    if (ret == KERN_SUCCESS && cPreviousPort != MACH_PORT_NULL)
        mach_port_deallocate(mach_task_self(), cPreviousPort);

    return ret;
}

- (void)handleMachMessage:(void *)msgPtr
{
    union {
        mach_msg_header_t header;
        p1_preview_msg_t preview_msg;
        mach_no_senders_notification_t no_senders;
    } *msg = msgPtr;

    switch (msg->header.msgh_id) {
        case p1_preview_set_surface_msg_id: {
            IOSurfaceRef surfaceRef = NULL;
            if (msg->header.msgh_remote_port != MACH_PORT_NULL)
                surfaceRef = IOSurfaceLookupFromMachPort(msg->header.msgh_remote_port);
            [self.delegate previewSetSurface:surfaceRef];
            if (surfaceRef)
                CFRelease(surfaceRef);
            break;
        }

        case p1_preview_updated_msg_id:
            [self.delegate previewUpdated];
            break;

        case MACH_NOTIFY_NO_SENDERS:
            [self destroy];
            break;
    }

    mach_msg_destroy(&msg->header);
}

@end
