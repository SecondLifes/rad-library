unit rad.hash;

interface
uses Hash
//,dxhash
;
type

  THash = class
   public
    class function md5(const v:string):string ; static;
  end;

implementation

{ THash }

class function THash.md5(const v: string): string;
begin
 Result:=THashMD5.GetHashString(v);
end;

end.
