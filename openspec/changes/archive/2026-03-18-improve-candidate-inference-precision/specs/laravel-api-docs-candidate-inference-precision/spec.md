## ADDED Requirements

### Requirement: Candidate inference MUST use method-level impact mapping for service changes
The system MUST infer `updated` endpoints from changed `Service::method` calls instead of marking all endpoints that reference the same service file.

#### Scenario: Service method change maps only to calling actions
- **WHEN** git diff indicates `UserService::register` changed within the selected range
- **THEN** only endpoints whose `Controller@action` actually calls `UserService::register` are emitted as `status=updated`

#### Scenario: Unrelated methods in same service are excluded
- **WHEN** `UserService.php` changed but only method `register` is impacted
- **THEN** endpoints that only call `UserService::login` or other unchanged methods MUST NOT be emitted as `status=updated`

### Requirement: Controller impact detection SHALL bind to route action scope
The system SHALL evaluate dependency impact at `Controller@action` scope, not whole-controller file scope.

#### Scenario: Action-scoped controller diff maps to single endpoint
- **WHEN** controller diff lines map to action `DriverController@login`
- **THEN** only the route bound to `DriverController@login` is emitted as `status=updated`

#### Scenario: Other actions in same controller remain unchanged
- **WHEN** no diff or dependency hit exists for `DriverController@register`
- **THEN** its endpoint MUST NOT be emitted as `status=updated`

### Requirement: Request, Resource, and Exception impacts MUST be action-bound
The system MUST mark `updated` only when changed Request/Resource/Exception classes are actually referenced by the affected action.

#### Scenario: Request change updates only bound action
- **WHEN** `DriverLoginRequest` changed and it is used by `DriverController@login`
- **THEN** only the endpoint bound to `DriverController@login` is emitted as `status=updated`

#### Scenario: Exception change updates only matching error flow
- **WHEN** `UserRegisterException` changed and only `UserController@register` catches or throws it in call flow
- **THEN** only that endpoint is emitted as `status=updated`

### Requirement: Candidate output MUST include structured explainability signals
Each candidate MUST include structured reason signals so users can verify why an endpoint was included.

#### Scenario: Service method hit signal exists
- **WHEN** an endpoint is marked updated due to service method mapping
- **THEN** output includes a signal indicating changed service method and matched action

#### Scenario: Action-bound dependency signal exists
- **WHEN** an endpoint is marked updated due to request/resource/exception impact
- **THEN** output includes dependency-specific action-bound hit signals in `signals`
