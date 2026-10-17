{ Include from SkiaCanvasTests.pas after the other test includes. }
procedure T_EmfFuzzSmoke;
begin
  Check(RunEmfFuzzSmoke($13579BDF, 300), 'EMF parser fuzz smoke (fixed seed)');
end;
