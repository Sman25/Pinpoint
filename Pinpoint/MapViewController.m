//
//  MapViewController.m
//  Pinpoint
//
//  Created by Spencer Atkin on 8/1/15.
//  Copyright (c) 2015 Pinpoint-DCHacks. All rights reserved.
//

#import "MapViewController.h"
#import "UserData.h"
#import <Firebase/Firebase.h>
#import "FirebaseHelper.h"
#import "GeoFire+Private.h"

@interface MapViewController ()
@property (strong, nonatomic) CLLocationManager *manager;
@property (strong, nonatomic) FIRDatabaseReference *firebase;
@property (strong, nonatomic) GeoFire *geofire;
@property (strong, nonatomic) NSString *name;
@property (strong, nonatomic) NSString *number;
@property (nonatomic) FirebaseHandle handle;

@property (weak, nonatomic) IBOutlet UILabel *distanceLabel;
@end

@implementation MapViewController

BOOL allowed = false;
UIAlertController *waitAlert;
MKPointAnnotation *annotation;

// TODO: Get first location and if access is allowed, create an event listener to update location every time the location node is changed
- (void)viewDidLoad {
    [super viewDidLoad];
    self.manager = [[CLLocationManager alloc] init];
    [self.manager setDelegate:self];
    annotation = [[MKPointAnnotation alloc] init];
    [self.mapView addAnnotation:annotation];
    self.name = [[NSUserDefaults standardUserDefaults] objectForKey:@"name"];
    self.number = [[NSUserDefaults standardUserDefaults] objectForKey:@"number"];
    self.firebase = [[[FIRDatabase database] reference] child:[NSString stringWithFormat:@"locations/%@", self.recipientId]];
    self.geofire = [[GeoFire alloc] initWithFirebaseRef:self.firebase];
    
    // Setup bar button item
    MKUserTrackingBarButtonItem *trackingButton = [[MKUserTrackingBarButtonItem alloc] initWithMapView:self.mapView];
    NSMutableArray *items = [[NSMutableArray alloc] initWithArray:[self.toolbar items]];
    [items insertObject:trackingButton atIndex:0];
    [self.toolbar setItems:items];
    [self readOneLocation];
    [self startRefreshingLocation];
    // Do any additional setup after loading the view.
}

- (void)readOneLocation {
    [FirebaseHelper authWithEmail:[UserData sharedInstance].email password:[UserData sharedInstance].password completion:^(FIRUser *user, NSError *error) {
        [self.geofire getLocationForKey:@"location" withCallback:^(CLLocation *location, NSError *error) {
            if (error == nil) {
                NSLog(@"Location successfully retrieved");
                // Annotation
                [UIView beginAnimations:nil context:NULL]; // animate the following:
                annotation.coordinate = location.coordinate; // move to new location
                [UIView setAnimationDuration:2.0f];
                [UIView commitAnimations];
                /*[UIView animateWithDuration:2.0f animations:^{
                 annotation.coordinate = location.coordinate;
                 } completion:nil];*/
                //[annotation setCoordinate:location.coordinate];
                [annotation setTitle:@"Last location"];
                NSDateFormatter *df = [[NSDateFormatter alloc] init];
                [df setDateStyle:NSDateFormatterNoStyle];
                [df setTimeStyle:NSDateFormatterMediumStyle];
                [annotation setSubtitle:[df stringFromDate:location.timestamp]];
                //[self removeAllAnnotations];
                
                
                // Distance label
                CLLocation *currentLocation = self.mapView.userLocation.location;
                [self.distanceLabel setText:[NSString stringWithFormat:@"%.02f meters", [currentLocation distanceFromLocation:location]]];
            }
            else {
                NSLog(@"Error fetching location %@", error);
            }
        }];
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self checkAlwaysAuthorization];
    [self startRefreshingLocation];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.isMovingFromParentViewController) {
        [self stopRefreshingLocation];
    }
}

- (void)startRefreshingLocation {
    NSLog(@"Recipient: %@", self.recipientId);
    self.handle = [[self.firebase child:@"location/l/0"] observeEventType:FIRDataEventTypeValue withBlock:^(FIRDataSnapshot *snapshot) {
        [self readOneLocation];
    }];
    [self.manager startUpdatingLocation];
}

- (void)stopRefreshingLocation {
    [self.firebase removeObserverWithHandle:self.handle];
    [self.manager stopUpdatingLocation];
}

- (void)removeAllAnnotations {
    id userLocation = [self.mapView userLocation];  // Current location
    NSMutableArray *pins = [[NSMutableArray alloc] initWithArray:[self.mapView annotations]];   // All annotations on the map
    if (userLocation != nil) {
        [pins removeObject:userLocation]; // Remove user location from the annotations
    }
    [self.mapView removeAnnotations:pins];
    // Removes all annotations from the mapview, excluding user location
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    if ([annotation.title isEqualToString:@"Last location"]) {
    [self.distanceLabel setText:[NSString stringWithFormat:@"%.02f meters", [[locations lastObject] distanceFromLocation:[[CLLocation alloc] initWithLatitude:annotation.coordinate.latitude longitude:annotation.coordinate.longitude]]]];
    }
}

- (void)checkAlwaysAuthorization {
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    // If the status is denied or only granted for when in use, display an alert
    if (status == kCLAuthorizationStatusAuthorizedWhenInUse || status == kCLAuthorizationStatusDenied) {
        NSLog(@"Denied");
        NSString *title =  (status == kCLAuthorizationStatusDenied) ? @"Location services are off" : @"Background location is not enabled";
        NSString *message = @"To use background location you must turn on 'Always' in the Location Services Settings";
        
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
        UIAlertAction *settingsAction = [UIAlertAction actionWithTitle:@"Settings" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
        }];
        [alertController addAction:cancelAction];
        [alertController addAction:settingsAction];
        [self presentViewController:alertController animated:YES completion:nil];
    }
    
    else if (status == kCLAuthorizationStatusNotDetermined) {
        NSLog(@"Not determined");
        if([self.manager respondsToSelector:@selector(requestAlwaysAuthorization)]) {
            [self.manager requestAlwaysAuthorization];
        }
    }
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
